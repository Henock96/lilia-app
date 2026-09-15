import 'package:lilia_app/models/cart.dart';
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

  const CartItemPreview({
    required this.productId,
    required this.variantId,
    required this.product,
    required this.variant,
  });

  /// Depuis la fiche produit ou une carte de catalogue.
  factory CartItemPreview.fromProduct(Product product, ProductVariant variant) {
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
    );
  }

  /// Depuis une ligne de panier existante — utilisé par la restauration d'un
  /// brouillon, qui repart d'articles déjà décrits.
  factory CartItemPreview.fromCartItem(CartItem item) => CartItemPreview(
    productId: item.productId,
    variantId: item.variantId,
    product: item.product,
    variant: item.variant,
  );
}

/// Identifiant local d'une ligne ajoutée mais pas encore confirmée.
///
/// Il ne fuit jamais vers le serveur : la réponse de `POST /cart/add` remplace
/// le panier entier, donc la ligne provisoire et son identifiant disparaissent
/// avec elle. Il est reconnaissable pour que rien ne tente un
/// `DELETE /cart/items/optimistic-…` sur une ligne qui n'existe pas encore.
String optimisticItemId(String variantId) => 'optimistic-$variantId';

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
/// Si la variante est déjà au panier hors menu, on incrémente sa ligne — c'est
/// ce que fait `CartItemsService.addItem`. Sinon on crée une ligne provisoire.
Cart applyAddItem(Cart? cart, CartItemPreview preview, int quantity) {
  final base = cart ?? _panierVide();
  final index = base.items.indexWhere(
    (i) => i.variantId == preview.variantId && i.menuId == null,
  );

  final items = List<CartItem>.of(base.items);
  if (index >= 0) {
    items[index] = items[index].copyWith(
      quantite: items[index].quantite + quantity,
    );
  } else {
    items.add(
      CartItem(
        id: optimisticItemId(preview.variantId),
        cartId: base.id,
        productId: preview.productId,
        variantId: preview.variantId,
        quantite: quantity,
        createdAt: DateTime.now(),
        product: preview.product,
        variant: preview.variant,
      ),
    );
  }
  return base.copyWith(items: items);
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
