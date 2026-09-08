// Couverture de l'écran « Mode de livraison » après la remédiation
// AUDIT_2026-08-01 : les `RadioListTile` portaient `groupValue`/`onChanged`,
// dépréciés depuis Flutter 3.32 ; l'état du groupe est désormais porté par un
// `RadioGroup<bool>` ancêtre.
//
// Ces tests montent la page avec des providers surchargés — aucun appel réseau,
// aucune donnée de prod touchée.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/quartiers/application/quartiers_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

const _restaurantId = 'resto-1';

void main() {
  group('DeliveryOptionsPage — RadioGroup', () {
    testWidgets('expose un RadioGroup<bool> et deux options', (tester) async {
      await _pumpPage(tester);

      expect(find.byType(RadioGroup<bool>), findsOneWidget);
      expect(find.byType(RadioListTile<bool>), findsNWidgets(2));
      expect(find.text('Livraison a domicile'), findsOneWidget);
      expect(find.textContaining('Retrait'), findsWidgets);
    });

    testWidgets('la livraison est sélectionnée par défaut', (tester) async {
      await _pumpPage(tester);

      expect(_groupValue(tester), isTrue);
    });

    testWidgets('taper sur Retrait bascule le groupe', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.textContaining('Retrait').first);
      await tester.pump();

      expect(_groupValue(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retour sur Livraison après un Retrait', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.textContaining('Retrait').first);
      await tester.pump();
      await tester.tap(find.text('Livraison a domicile'));
      await tester.pump();

      expect(_groupValue(tester), isTrue);
    });

    testWidgets('HOME_COOK masque l\'option retrait', (tester) async {
      // Un vendeur maison n'a pas de point de vente physique : le retrait est
      // masqué et le mode livraison forcé.
      await _pumpPage(tester, vendorType: VendorType.HOME_COOK);

      expect(find.byType(RadioGroup<bool>), findsOneWidget);
      expect(find.byType(RadioListTile<bool>), findsOneWidget);
      expect(find.textContaining('Retrait'), findsNothing);
      expect(_groupValue(tester), isTrue);
    });

    testWidgets('panier vide → message, pas de RadioGroup', (tester) async {
      await _pumpPage(tester, emptyCart: true);

      expect(find.text('Votre panier est vide'), findsOneWidget);
      expect(find.byType(RadioGroup<bool>), findsNothing);
    });
  });
}

/// Valeur portée par le `RadioGroup<bool>` — c'est elle qui pilote la sélection
/// depuis que `groupValue` a quitté les tuiles.
bool? _groupValue(WidgetTester tester) =>
    tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue;

Future<void> _pumpPage(
  WidgetTester tester, {
  VendorType vendorType = VendorType.RESTAURANT,
  bool emptyCart = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider.overrideWith(
          () => _FakeCart(emptyCart ? null : _cart()),
        ),
        quartiersListProvider.overrideWith((ref) async => _quartiers),
        adresseControllerProvider.overrideWith(() => _FakeAdresses()),
        restaurantControllerProvider(
          _restaurantId,
        ).overrideWith((ref) async => _restaurant(vendorType)),
      ],
      child: MaterialApp(home: const DeliveryOptionsPage()),
    ),
  );
  // Les providers async se résolvent en microtask, et `flutter_animate` pose
  // des timers d'entrée qu'il faut laisser expirer — sinon le test échoue sur
  // « pending timers ». On ne peut pas utiliser `pumpAndSettle` : certaines
  // animations de l'app tournent en boucle.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _FakeCart extends CartController {
  _FakeCart(this._cart);
  final Cart? _cart;

  @override
  Future<Cart?> build() async => _cart;
}

class _FakeAdresses extends AdresseController {
  @override
  Future<List<Adresse>> build() async => _adresses;
}

Cart _cart() => Cart(
  id: 'cart-1',
  userId: 'user-1',
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
  items: [
    CartItem(
      id: 'item-1',
      cartId: 'cart-1',
      productId: 'prod-1',
      variantId: 'var-1',
      quantite: 2,
      createdAt: DateTime(2026, 8, 1),
      product: ProductItem(nom: 'Poulet braisé', restaurantId: _restaurantId),
      variant: VariantItem(label: 'Normal', prix: 3000),
    ),
  ],
);

Restaurant _restaurant(VendorType type) => Restaurant(
  id: _restaurantId,
  name: 'Chez Maman Lili',
  address: 'Poto-Poto, Brazzaville',
  products: const [],
  categoriesMap: const {},
  vendorType: type,
);

final _quartiers = [
  Quartier(id: 'q-1', nom: 'Poto-Poto', ville: 'Brazzaville'),
  Quartier(id: 'q-2', nom: 'Bacongo', ville: 'Brazzaville'),
];

final _adresses = [
  Adresse(
    id: 'adr-1',
    rue: '12 rue de la Paix',
    ville: 'Brazzaville',
    country: 'CG',
    userId: 'user-1',
    quartierId: 'q-1',
  ),
];
