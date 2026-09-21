// **Le minimum de commande, dit dans le panier et non au dernier tap.**
//
// La valeur était affichée sur la fiche vendeur et sur sa carte, puis oubliée.
// Le serveur, lui, refuse au checkout (`validateMinimumOrderAmount`) : le
// client l'apprenait après avoir choisi un mode de livraison, un quartier, une
// adresse, saisi son téléphone, parfois un code promo. Cinq écrans pour un
// refus connu dès le panier.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/presentation/cart_screen.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/utils/currency.dart';

const _restaurantId = 'resto-1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sous le minimum : le bouton est inactif et le manque est nommé',
      (tester) async {
    // Panier à 3 000, minimum à 5 000.
    await _pump(tester, sousTotal: 3000, minimum: 5000);

    expect(
      find.textContaining('Ajoutez encore'),
      findsOneWidget,
      reason: 'le client doit lire le geste, pas la règle',
    );
    expect(
      // `formatPrice` et non une chaîne littérale : le séparateur de milliers
      // est une espace fine insécable (U+202F), pas une espace ordinaire.
      find.textContaining(formatPrice(2000)),
      findsOneWidget,
      reason: 'le manque, calculé pour lui — pas le seuil à soustraire',
    );
    expect(_boutonCommande(tester).onPressed, isNull);
  });

  testWidgets('au-dessus du minimum : rien ne s’affiche, le bouton est actif',
      (tester) async {
    await _pump(tester, sousTotal: 6000, minimum: 5000);

    expect(find.textContaining('Ajoutez encore'), findsNothing);
    expect(_boutonCommande(tester).onPressed, isNotNull);
  });

  testWidgets('pile au minimum : c’est atteint', (tester) async {
    await _pump(tester, sousTotal: 5000, minimum: 5000);

    expect(find.textContaining('Ajoutez encore'), findsNothing);
    expect(_boutonCommande(tester).onPressed, isNotNull);
  });

  testWidgets('vendeur sans minimum : rien ne change', (tester) async {
    await _pump(tester, sousTotal: 100, minimum: 0);

    expect(find.textContaining('Ajoutez encore'), findsNothing);
    expect(_boutonCommande(tester).onPressed, isNotNull);
  });

  testWidgets('fiche vendeur indisponible : on ne barre pas la route',
      (tester) async {
    // On ne connaît pas le minimum. Le serveur reste l'arbitre ; bloquer sur
    // une information qu'on n'a pas transformerait une panne de lecture en
    // commande impossible.
    await _pump(tester, sousTotal: 100, minimum: null);

    expect(find.textContaining('Ajoutez encore'), findsNothing);
    expect(_boutonCommande(tester).onPressed, isNotNull);
  });
}

ElevatedButton _boutonCommande(WidgetTester tester) =>
    tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Passer la commande'),
        matching: find.byType(ElevatedButton),
      ),
    );

/// [minimum] `null` = la fiche vendeur n'a pas pu être lue.
Future<void> _pump(
  WidgetTester tester, {
  required double sousTotal,
  required double? minimum,
}) async {
  // On allonge la surface sans la rétrécir : 800 × 1600 dp.
  //
  // La hauteur par défaut (600 dp) ne suffit pas à l'écran du panier. Mais il
  // ne faut surtout pas ramener la **largeur** à celle d'un téléphone : le
  // pied « déborderait » alors de 137 px, faux positif intégral.
  // `flutter_test` rend chaque glyphe comme un carré de la taille de la
  // police, si bien que « Passer la commande » y occupe 340 dp au lieu
  // d'environ 140 avec la vraie police. À cette largeur, on mesurerait la
  // police de test, pas la mise en page.
  tester.view.physicalSize = const Size(2400, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider.overrideWith(() => _FakeCart(_cart(sousTotal))),
        restaurantControllerProvider(_restaurantId).overrideWith(
          (ref) async => minimum == null
              ? throw Exception('vendeur injoignable')
              : _restaurant(minimum),
        ),
      ],
      child: const MaterialApp(home: CartScreen()),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _FakeCart extends CartController {
  _FakeCart(this._cart);
  final Cart _cart;

  @override
  Future<Cart?> build() async => _cart;
}

Cart _cart(double sousTotal) => Cart(
      id: 'cart-1',
      userId: 'user-1',
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
      items: [
        CartItem(
          id: 'item-1',
          cartId: 'cart-1',
          productId: 'prod-1',
          variantId: 'var-1',
          quantite: 1,
          createdAt: DateTime(2026, 9, 21),
          product: ProductItem(nom: 'Poulet braisé', restaurantId: _restaurantId),
          variant: VariantItem(label: 'Normal', prix: sousTotal.toInt()),
        ),
      ],
    );

Restaurant _restaurant(double minimum) => Restaurant(
      id: _restaurantId,
      name: 'Chez Lilia',
      address: 'Brazzaville',
      products: const [],
      categoriesMap: const {},
      minimumOrderAmount: minimum,
    );
