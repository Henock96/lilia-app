import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/menu.dart';
import 'package:lilia_app/models/produit.dart';

/// Logique de mutation optimiste — testée sans réseau, sans widget, sans
/// Riverpod. C'est elle qui décide ce que le client voit entre son tap et la
/// réponse du serveur : elle doit produire exactement ce que
/// `CartItemsService.addItem` produirait.
void main() {
  CartItemPreview apercu({
    String variantId = 'var-1',
    String restaurantId = 'resto-1',
    bool madeToOrder = false,
    int prix = 3500,
  }) => CartItemPreview(
    productId: 'prod-$variantId',
    variantId: variantId,
    product: ProductItem(
      nom: 'Poulet',
      restaurantId: restaurantId,
      madeToOrder: madeToOrder,
    ),
    variant: VariantItem(label: 'Normale', prix: prix),
  );

  Cart panier(List<CartItem> items) => Cart(
    id: 'cart-1',
    userId: 'user-1',
    items: items,
    createdAt: DateTime(2026, 9, 8),
    updatedAt: DateTime(2026, 9, 8),
  );

  CartItem ligne({
    String id = 'item-1',
    String variantId = 'var-1',
    int quantite = 1,
    String restaurantId = 'resto-1',
    bool madeToOrder = false,
    String? menuId,
  }) => CartItem(
    id: id,
    cartId: 'cart-1',
    productId: 'prod-$variantId',
    variantId: variantId,
    menuId: menuId,
    quantite: quantite,
    createdAt: DateTime(2026, 9, 8),
    product: ProductItem(
      nom: 'Poulet',
      restaurantId: restaurantId,
      madeToOrder: madeToOrder,
    ),
    variant: VariantItem(label: 'Normale', prix: 3500),
  );

  group('validateAddItem', () {
    test('panier vide : rien à refuser', () {
      expect(validateAddItem(null, apercu()), isNull);
      expect(validateAddItem(panier([]), apercu()), isNull);
    });

    test('même vendeur, même mode : accepté', () {
      expect(validateAddItem(panier([ligne()]), apercu(variantId: 'var-2')),
          isNull);
    });

    test('autre vendeur : refusé', () {
      final refus = validateAddItem(
        panier([ligne()]),
        apercu(variantId: 'var-2', restaurantId: 'resto-2'),
      );
      expect(refus, contains('une seule boutique'));
    });

    test('mode incompatible : le message dit lequel des deux gêne', () {
      // Panier immédiat + produit sur commande.
      expect(
        validateAddItem(
          panier([ligne()]),
          apercu(variantId: 'var-2', madeToOrder: true),
        ),
        contains('déjà des produits immédiats'),
      );
      // Panier sur commande + produit immédiat.
      expect(
        validateAddItem(
          panier([ligne(madeToOrder: true)]),
          apercu(variantId: 'var-2'),
        ),
        contains('déjà des produits sur commande'),
      );
    });

    test(
      'le stock n\'est PAS validé localement : il a pu bouger depuis '
      'le chargement du catalogue',
      () {
        // Aucun champ de stock n'entre dans la décision — refuser sur une
        // donnée périmée ferait perdre des ventes possibles.
        expect(validateAddItem(panier([ligne()]), apercu()), isNull);
      },
    );
  });

  group('applyAddItem', () {
    test('panier vide : crée une ligne provisoire reconnaissable', () {
      final resultat = applyAddItem(null, apercu(), 2);
      expect(resultat.items.single.quantite, 2);
      expect(isOptimisticItemId(resultat.items.single.id), isTrue);
      expect(resultat.totalItems, 2);
    });

    test('variante déjà présente : incrémente, ne duplique pas', () {
      final resultat = applyAddItem(
        panier([ligne(quantite: 2)]),
        apercu(),
        3,
      );
      expect(resultat.items, hasLength(1));
      expect(resultat.items.single.quantite, 5);
      expect(
        resultat.items.single.id,
        'item-1',
        reason: 'La ligne serveur existante garde son identifiant.',
      );
    });

    test('une ligne de menu portant la même variante n\'est pas touchée', () {
      // `CartItemsService.addItem` cherche `menuId: null` : un article de menu
      // vit sa propre vie, et l'incrémenter changerait la composition du menu.
      final resultat = applyAddItem(
        panier([ligne(id: 'item-menu', menuId: 'menu-1', quantite: 1)]),
        apercu(),
        1,
      );
      expect(resultat.items, hasLength(2));
      expect(resultat.items.first.menuId, 'menu-1');
      expect(resultat.items.first.quantite, 1);
    });

    test('le panier d\'origine n\'est pas muté', () {
      final origine = panier([ligne(quantite: 1)]);
      applyAddItem(origine, apercu(), 4);
      expect(
        origine.items.single.quantite,
        1,
        reason: 'Sans copie, le rollback restaurerait un instantané déjà '
            'modifié — donc ne restaurerait rien.',
      );
    });
  });

  group('applySetQuantity / applyRemoveItem', () {
    test('fixe la quantité de la bonne ligne', () {
      final resultat = applySetQuantity(
        panier([ligne(id: 'a'), ligne(id: 'b', variantId: 'var-2')]),
        'b',
        7,
      );
      expect(resultat!.items.firstWhere((i) => i.id == 'a').quantite, 1);
      expect(resultat.items.firstWhere((i) => i.id == 'b').quantite, 7);
    });

    test('quantité nulle : la ligne disparaît, comme côté repository', () {
      final resultat = applySetQuantity(panier([ligne(id: 'a')]), 'a', 0);
      expect(resultat!.items, isEmpty);
    });

    test('supprime la bonne ligne', () {
      final resultat = applyRemoveItem(
        panier([ligne(id: 'a'), ligne(id: 'b', variantId: 'var-2')]),
        'a',
      );
      expect(resultat!.items.single.id, 'b');
    });

    test('panier absent : rien à faire, pas de crash', () {
      expect(applySetQuantity(null, 'a', 3), isNull);
      expect(applyRemoveItem(null, 'a'), isNull);
    });
  });

  group('MenuCartPreview.fromMenu — le miroir de CartMenusService', () {
    Product produit(String id, {List<ProductVariant> variants = const []}) =>
        Product(
          id: id,
          name: 'Produit $id',
          description: '',
          prixOriginal: 1500,
          imageUrl: null,
          restaurantId: 'resto-1',
          categoryId: null,
          isAvailable: true,
          variants: variants,
        );

    MenuDuJour menu(List<MenuProduct> produits, {double prix = 4000}) =>
        MenuDuJour(
          id: 'menu-1',
          nom: 'Combo midi',
          prix: prix,
          dateDebut: DateTime(2026, 9, 19),
          dateFin: DateTime(2026, 9, 20),
          isActive: true,
          restaurantId: 'resto-1',
          restaurant: MenuRestaurant(id: 'resto-1', nom: 'Chez Awa'),
          products: produits,
          createdAt: DateTime(2026, 9, 19),
          updatedAt: DateTime(2026, 9, 19),
        );

    MenuProduct ligne(Product p) => MenuProduct(
      id: 'mp-${p.id}',
      menuId: 'menu-1',
      productId: p.id,
      ordre: 0,
      product: p,
      createdAt: DateTime(2026, 9, 19),
    );

    ProductVariant variante(String id, {double prix = 1500}) =>
        ProductVariant(id: id, label: 'Normale', prix: prix);

    /// La règle du serveur, mot pour mot : une ligne par produit, la PREMIÈRE
    /// variante de chacun.
    test('une ligne par produit, sur sa première variante', () {
      final preview = MenuCartPreview.fromMenu(
        menu([
          ligne(produit('a', variants: [variante('va1'), variante('va2')])),
          ligne(produit('b', variants: [variante('vb1')])),
        ]),
      )!;

      expect(preview.lines.map((l) => l.variantId), ['va1', 'vb1']);
      expect(preview.menuId, 'menu-1');
      expect(preview.menu.prix, 4000);
    });

    /// `CartMenusService` lève « n'a pas de variante disponible ». Le client
    /// s'arrête au même endroit, plutôt que de poser un panier faux.
    test('un produit sans variante rend null', () {
      expect(
        MenuCartPreview.fromMenu(
          menu([
            ligne(produit('a', variants: [variante('va1')])),
            ligne(produit('b')),
          ]),
        ),
        isNull,
      );
    });

    test('un menu vide rend null', () {
      expect(MenuCartPreview.fromMenu(menu([])), isNull);
    });

    /// ⚠️ Le prix du menu n'est PAS la somme de ses produits — c'est tout
    /// l'intérêt d'un menu, et le piège du calcul. `Cart.totalPrice` facture le
    /// groupe au prix du menu ; encore faut-il que `MenuInfo` le porte.
    test('le panier obtenu est facturé au prix du MENU', () {
      final preview = MenuCartPreview.fromMenu(
        menu([
          ligne(produit('a', variants: [variante('va1', prix: 2500)])),
          ligne(produit('b', variants: [variante('vb1', prix: 2500)])),
        ]),
      )!;

      final panier = applyAddMenu(null, preview, 2);
      expect(panier.items, hasLength(2));
      expect(panier.totalItems, 2); // 2 menus, pas 4 produits
      expect(panier.totalPrice, 8000); // 2 x 4000, pas 2 x 5000
    });

    test('retirer le menu retire toutes ses lignes', () {
      final preview = MenuCartPreview.fromMenu(
        menu([
          ligne(produit('a', variants: [variante('va1')])),
          ligne(produit('b', variants: [variante('vb1')])),
        ]),
      )!;
      final panier = applyAddMenu(null, preview, 1);

      expect(applyRemoveMenu(panier, 'menu-1')!.items, isEmpty);
      expect(applySetMenuQuantity(panier, 'menu-1', 0)!.items, isEmpty);
      expect(
        applySetMenuQuantity(panier, 'menu-1', 3)!.items.every(
          (i) => i.quantite == 3,
        ),
        isTrue,
      );
    });
  });
}
