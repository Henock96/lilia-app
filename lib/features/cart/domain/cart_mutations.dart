import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/menu.dart';
import 'package:lilia_app/models/modifier.dart';
import 'package:lilia_app/models/produit.dart';

/// Ce qu'il faut savoir d'un article pour l'afficher dans le panier **avant**
/// que le serveur n'ait répondu.
///
/// Exactement les champs que `CART_INCLUDE` renvoie côté backend, ni plus ni
/// moins : afficher davantage inventerait de la donnée, afficher moins ferait
/// clignoter la ligne quand la réponse serveur arrive.
class CartItemPreview {
  final String productId;
  final String variantId;
  final ProductItem product;
  final VariantItem variant;

  /// F3-09 — options choisies, avec nom et supplément du catalogue pour
  /// l'affichage immédiat. Seuls `optionId` et `quantity` partent au serveur.
  final List<LineOption> options;

  const CartItemPreview({
    required this.productId,
    required this.variantId,
    required this.product,
    required this.variant,
    this.options = const [],
  });

  /// Ce qui part au serveur : identifiants et quantités, rien d'autre.
  List<SelectedOption> get selection => [for (final o in options) o.selected];

  /// Identité locale de la sélection — même forme que la signature serveur.
  String get optionsKey => selectionKey(selection);

  /// Valeur unitaire des options (analytics, affichage).
  int get optionsValue =>
      options.fold(0, (sum, o) => sum + o.priceDeltaXaf * o.quantity);

  /// Depuis la fiche produit ou une carte de catalogue.
  factory CartItemPreview.fromProduct(
    Product product,
    ProductVariant variant, {
    List<LineOption> options = const [],
  }) {
    return CartItemPreview(
      productId: product.id,
      variantId: variant.id,
      product: ProductItem(
        nom: product.name,
        imageUrl: product.imageUrl,
        restaurantId: product.restaurantId,
        madeToOrder: product.madeToOrder,
      ),
      variant: VariantItem(
        label: variant.displayLabel,
        prix: variant.prix.round(),
      ),
      options: options,
    );
  }

  /// Depuis une ligne de panier existante — utilisé par la restauration d'un
  /// brouillon, qui repart d'articles déjà décrits.
  factory CartItemPreview.fromCartItem(CartItem item) => CartItemPreview(
    productId: item.productId,
    variantId: item.variantId,
    product: item.product,
    variant: item.variant,
    options: item.options,
  );
}

/// Identifiant local d'une ligne ajoutée mais pas encore confirmée.
///
/// Il ne fuit jamais vers le serveur : la réponse de `POST /cart/add` remplace
/// le panier entier, donc la ligne provisoire et son identifiant disparaissent
/// avec elle. Il est reconnaissable pour que rien ne tente un
/// `DELETE /cart/items/optimistic-…` sur une ligne qui n'existe pas encore.
String optimisticItemId(String variantId, [String optionsKey = '']) =>
    optionsKey.isEmpty
    ? 'optimistic-$variantId'
    : 'optimistic-$variantId-$optionsKey';

bool isOptimisticItemId(String id) => id.startsWith('optimistic-');

/// Pourquoi cet ajout est impossible **sans demander au serveur**, ou `null`.
///
/// ## Ce qu'on valide ici, et ce qu'on ne valide pas
///
/// Les deux règles ci-dessous ne dépendent que du panier courant et du produit
/// qu'on tient en main : elles ne peuvent pas changer entre l'affichage de la
/// fiche et le tap. Les refuser localement épargne un aller-retour **et** rend
/// le message immédiat.
///
/// Le stock et la disponibilité, eux, peuvent avoir bougé depuis le chargement
/// du catalogue. Ils restent arbitrés par le serveur : le client ne s'autorise
/// pas à refuser un ajout sur une donnée qu'il sait potentiellement périmée —
/// il refuserait des ventes possibles.
String? validateAddItem(Cart? cart, CartItemPreview preview) {
  final items = cart?.items ?? const <CartItem>[];
  if (items.isEmpty) return null;

  if (items.first.product.restaurantId != preview.product.restaurantId) {
    return 'Vous ne pouvez commander que dans une seule boutique à la fois. '
        'Videz votre panier pour changer de vendeur.';
  }

  if (items.first.product.madeToOrder != preview.product.madeToOrder) {
    return preview.product.madeToOrder
        ? 'Votre panier contient déjà des produits immédiats. Terminez cette '
              'commande ou videz votre panier pour ajouter un produit sur commande.'
        : 'Votre panier contient déjà des produits sur commande. Terminez cette '
              'commande ou videz votre panier pour ajouter un produit immédiat.';
  }

  return null;
}

/// Le panier tel qu'il sera si le serveur accepte l'ajout.
///
/// Si la même variante **avec la même sélection d'options** est déjà au panier
/// hors menu, on incrémente sa ligne — c'est ce que fait
/// `CartItemsService.addItem` (identité = variante + signature, F3-09).
/// Sinon on crée une ligne provisoire : « Poulet + Alloco » et « Poulet +
/// Frites » sont deux lignes.
Cart applyAddItem(Cart? cart, CartItemPreview preview, int quantity) {
  final base = cart ?? _panierVide();
  final key = preview.optionsKey;
  final index = base.items.indexWhere(
    (i) =>
        i.variantId == preview.variantId &&
        i.menuId == null &&
        i.optionsSignature == key,
  );

  final items = List<CartItem>.of(base.items);
  if (index >= 0) {
    items[index] = items[index].copyWith(
      quantite: items[index].quantite + quantity,
    );
  } else {
    items.add(
      CartItem(
        id: optimisticItemId(preview.variantId, key),
        cartId: base.id,
        productId: preview.productId,
        variantId: preview.variantId,
        quantite: quantity,
        createdAt: DateTime.now(),
        product: preview.product,
        variant: preview.variant,
        optionsSignature: key,
        options: preview.options,
      ),
    );
  }
  return base.copyWith(items: items);
}

/// Ce qu'il faut savoir d'un menu pour le poser dans un panier local.
///
/// Le même découpage que `CartMenusService.addMenu` côté serveur : **une ligne
/// par produit du menu**, la première variante de chacun, toutes portant le
/// `menuId` et la fiche du menu. Ce n'est pas une invention de contenu — c'est
/// la reprise d'une règle déterministe de vingt lignes, et `Cart.totalPrice`
/// sait déjà facturer un groupe au prix du menu et non à la somme de ses
/// produits.
class MenuCartPreview {
  final String menuId;
  final MenuInfo menu;

  /// Les lignes à créer, dans l'ordre du menu. Vide si un produit n'a aucune
  /// variante — cas que le serveur refuse, et qu'on refuse donc aussi.
  final List<CartItemPreview> lines;

  const MenuCartPreview({
    required this.menuId,
    required this.menu,
    required this.lines,
  });

  /// Décompose un menu du jour, ou rend `null` s'il ne peut pas l'être.
  ///
  /// `null` dans deux cas, les mêmes que ceux que le serveur refuse : un menu
  /// sans produit, ou un produit sans variante (`CartMenusService` lève alors
  /// « n'a pas de variante disponible »). Mieux vaut le dire avant l'ajout que
  /// de poser un panier faux — et le repli sur l'ajout serveur reste ouvert
  /// pour un client connecté.
  static MenuCartPreview? fromMenu(MenuDuJour menu) {
    if (menu.products.isEmpty) return null;

    final lignes = <CartItemPreview>[];
    for (final mp in menu.products) {
      // `variants.first` : la règle du serveur, mot pour mot.
      if (mp.product.variants.isEmpty) return null;
      final variante = mp.product.variants.first;
      lignes.add(
        CartItemPreview(
          productId: mp.productId,
          variantId: variante.id,
          product: ProductItem(
            nom: mp.product.name,
            imageUrl: mp.product.imageUrl,
            restaurantId: menu.restaurantId,
            madeToOrder: mp.product.madeToOrder,
          ),
          variant: VariantItem(
            label: variante.displayLabel,
            prix: variante.prix.round(),
          ),
        ),
      );
    }

    return MenuCartPreview(
      menuId: menu.id,
      menu: MenuInfo(
        id: menu.id,
        nom: menu.nom,
        prix: menu.prix,
        imageUrl: menu.imageUrl,
      ),
      lines: lignes,
    );
  }
}

/// Identifiant local d'une ligne de menu non encore confirmée.
String optimisticMenuItemId(String menuId, String variantId) =>
    'optimistic-$menuId-$variantId';

/// Le panier tel qu'il sera si le serveur accepte l'ajout du menu.
///
/// Menu déjà présent → on incrémente la quantité de **toutes** ses lignes,
/// exactement comme `CartMenusService`. Sinon on crée le groupe.
Cart applyAddMenu(Cart? cart, MenuCartPreview preview, int quantity) {
  final base = cart ?? _panierVide();
  final dejaPresent = base.items.any((i) => i.menuId == preview.menuId);

  if (dejaPresent) {
    return base.copyWith(
      items: [
        for (final item in base.items)
          if (item.menuId == preview.menuId)
            item.copyWith(quantite: item.quantite + quantity)
          else
            item,
      ],
    );
  }

  return base.copyWith(
    items: [
      ...base.items,
      for (final ligne in preview.lines)
        CartItem(
          id: optimisticMenuItemId(preview.menuId, ligne.variantId),
          cartId: base.id,
          productId: ligne.productId,
          variantId: ligne.variantId,
          menuId: preview.menuId,
          quantite: quantity,
          createdAt: DateTime.now(),
          product: ligne.product,
          variant: ligne.variant,
          menu: preview.menu,
        ),
    ],
  );
}

/// Le panier tel qu'il sera après changement de quantité d'un menu.
Cart? applySetMenuQuantity(Cart? cart, String menuId, int quantity) {
  if (cart == null) return null;
  if (quantity <= 0) return applyRemoveMenu(cart, menuId);
  return cart.copyWith(
    items: [
      for (final item in cart.items)
        if (item.menuId == menuId) item.copyWith(quantite: quantity) else item,
    ],
  );
}

/// Le panier tel qu'il sera après retrait d'un menu — **toutes** ses lignes.
Cart? applyRemoveMenu(Cart? cart, String menuId) {
  if (cart == null) return null;
  return cart.copyWith(
    items: cart.items.where((item) => item.menuId != menuId).toList(),
  );
}

/// Le panier tel qu'il sera si le serveur accepte la nouvelle quantité.
/// Une quantité nulle ou négative retire la ligne — comme le fait le
/// repository, qui route alors vers `DELETE /cart/items/:id`.
Cart? applySetQuantity(Cart? cart, String cartItemId, int quantity) {
  if (cart == null) return null;
  if (quantity <= 0) return applyRemoveItem(cart, cartItemId);

  final items = [
    for (final item in cart.items)
      if (item.id == cartItemId) item.copyWith(quantite: quantity) else item,
  ];
  return cart.copyWith(items: items);
}

/// Le panier tel qu'il sera si le serveur accepte la suppression.
Cart? applyRemoveItem(Cart? cart, String cartItemId) {
  if (cart == null) return null;
  return cart.copyWith(
    items: cart.items.where((item) => item.id != cartItemId).toList(),
  );
}

Cart _panierVide() => Cart(
  id: 'optimistic-cart',
  userId: '',
  items: const [],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
