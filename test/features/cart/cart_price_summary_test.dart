// P3-11 — le prix annoncé avant le tunnel.
//
// Le panier affichait un nombre sans libellé ; le checkout y ajoutait 15 % de
// frais de service et la livraison. Ces tests fixent ce que le panier dit, et
// surtout ce qu'il refuse d'inventer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/domain/cart_price_preview.dart';
import 'package:lilia_app/features/cart/presentation/cart_price_summary.dart';
import 'package:lilia_app/features/cart/presentation/cart_screen.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/draft_order.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/utils/currency.dart';

const _restaurantId = 'resto-1';

PlatformSettings _bareme({
  double percent = 15,
  String mode = 'VENDOR_LEGACY',
  int? from,
}) => PlatformSettings(
  serviceFeePercent: percent,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 1,
  referrerBonusPoints: 1,
  deliveryPricingMode: mode,
  deliveryFeeFromXaf: from,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartPricePreview', () {
    test('annonce le taux serveur, sans calculer de montant (lot 5, F-40)', () {
      final p = CartPricePreview.compute(subTotal: 6333, settings: _bareme());
      expect(p.subTotal, 6333);
      expect(p.serviceFeePercentLabel, '15 %');
    });

    test('barème injoignable : aucun taux inventé', () {
      final p = CartPricePreview.compute(subTotal: 6000, settings: null);
      expect(p.serviceFeePercent, isNull);
      expect(p.serviceFeePercentLabel, isNull);
    });

    test('taux décimal lisible', () {
      final p = CartPricePreview.compute(
        subTotal: 1000,
        settings: _bareme(percent: 7.5),
      );
      expect(p.serviceFeePercentLabel, '7,5 %');
    });

    // D-4 — le panier annonce le taux de SA boutique (épicerie : le sien).
    test('taux de la boutique annoncé par le serveur : affiché', () {
      final p = CartPricePreview.compute(
        subTotal: 20000,
        settings: _bareme(),
        serviceFeePercent: 5,
      );
      expect(p.serviceFeePercentLabel, '5 %');
    });
  });

  group('pied du panier', () {
    testWidgets('sous-total, taux des frais et livraison vendeur', (
      tester,
    ) async {
      await _pump(tester, prix: 6000, quantite: 1, settings: _bareme());
      expect(find.text('Sous-total (1 article)'), findsOneWidget);
      // Ligne d'article et sous-total : un seul article, même montant.
      expect(find.text(formatPrice(6000)), findsWidgets);
      expect(find.text('Frais de service'), findsOneWidget);
      expect(find.text('15 % du sous-total'), findsOneWidget);
      expect(find.text('+ Livraison'), findsOneWidget);
      expect(find.text(formatPrice(1500)), findsOneWidget); // frais vendeur
      expect(find.textContaining('montant final'), findsOneWidget);
    });

    // Lot 5 (F-40) : aucun montant de frais ni total calculé localement.
    testWidgets('aucun montant estimé', (tester) async {
      await _pump(tester, prix: 6000, quantite: 1, settings: _bareme());
      expect(find.text(formatPrice(900)), findsNothing);
      expect(find.text(formatPrice(6900)), findsNothing);
      expect(find.textContaining('estimé'), findsNothing);
    });

    testWidgets('la quantité change le sous-total', (tester) async {
      await _pump(tester, prix: 2000, quantite: 3, settings: _bareme());
      expect(find.text('Sous-total (3 articles)'), findsOneWidget);
      expect(find.text(formatPrice(6000)), findsOneWidget);
    });

    testWidgets('mode plateforme : « Dès X », jamais un prix inventé', (
      tester,
    ) async {
      await _pump(
        tester,
        prix: 6000,
        quantite: 1,
        settings: _bareme(mode: 'PLATFORM', from: 1000),
      );
      expect(find.text('Dès ${formatPrice(1000)}'), findsOneWidget);
    });

    testWidgets('barème injoignable : frais annoncés, pas chiffrés', (
      tester,
    ) async {
      await _pump(tester, prix: 6000, quantite: 1, settings: null);
      expect(find.text('Calculés à l\'étape suivante'), findsOneWidget);
      // Le bouton reste actif : le checkout sait réessayer le barème.
      final bouton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Passer la commande'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(bouton.onPressed, isNotNull);
    });
  });

  group('commande en attente', () {
    // Le brouillon n'affichait que son sous-total : même récapitulatif que
    // le panier dont il sort.
    testWidgets('sous-total, taux des frais et livraison', (tester) async {
      final draft = DraftOrder(
        id: 'd-1',
        restaurantName: 'Chez Lilia',
        items: _cart(2000, 3).items,
        totalPrice: 6000,
        createdAt: DateTime(2026, 9, 30),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restaurantControllerProvider(
              _restaurantId,
            ).overrideWith((ref) async => _restaurant()),
            platformSettingsProvider.overrideWith((ref) async => _bareme()),
          ],
          child: MaterialApp(
            home: Scaffold(body: CartPriceSummary.draft(draft)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Sous-total (3 articles)'), findsOneWidget);
      expect(find.text('15 % du sous-total'), findsOneWidget);
      expect(find.text(formatPrice(1500)), findsOneWidget);
    });
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required int prix,
  required int quantite,
  required PlatformSettings? settings,
}) async {
  tester.view.physicalSize = const Size(2400, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider.overrideWith(
          () => _FakeCart(_cart(prix, quantite)),
        ),
        restaurantControllerProvider(
          _restaurantId,
        ).overrideWith((ref) async => _restaurant()),
        platformSettingsProvider.overrideWith(
          (ref) async =>
              settings ?? (throw Exception('/platform-settings injoignable')),
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

Cart _cart(int prix, int quantite) => Cart(
  id: 'cart-1',
  userId: 'user-1',
  createdAt: DateTime(2026, 9, 29),
  updatedAt: DateTime(2026, 9, 29),
  items: [
    CartItem(
      id: 'item-1',
      cartId: 'cart-1',
      productId: 'prod-1',
      variantId: 'var-1',
      quantite: quantite,
      createdAt: DateTime(2026, 9, 29),
      product: ProductItem(nom: 'Poulet braisé', restaurantId: _restaurantId),
      variant: VariantItem(label: 'Normal', prix: prix),
    ),
  ],
);

Restaurant _restaurant() => Restaurant(
  id: _restaurantId,
  name: 'Chez Lilia',
  address: 'Brazzaville',
  products: const [],
  categoriesMap: const {},
  fixedDeliveryFee: 1500,
);
