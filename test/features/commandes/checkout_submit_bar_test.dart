// P3-15 — le CTA du checkout reste au pied de l'écran, avec le total du
// récapitulatif, et n'arbitre rien : activation, envoi et refus viennent de
// la page (la garde de double envoi est testée dans
// `checkout_double_submit_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/presentation/checkout_page.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/checkout_submit_bar.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

const _restaurantId = 'resto-1';

Cart _panier() => Cart(
  id: 'panier-1',
  userId: 'uid-a',
  createdAt: DateTime(2026, 9, 29),
  updatedAt: DateTime(2026, 9, 29),
  items: [
    CartItem(
      id: 'ligne-1',
      cartId: 'panier-1',
      productId: 'prod-1',
      variantId: 'var-1',
      quantite: 2,
      createdAt: DateTime(2026, 9, 29),
      product: ProductItem(nom: 'Poulet braisé', restaurantId: _restaurantId),
      variant: VariantItem(label: 'Normale', prix: 10000),
    ),
  ],
);

class _FauxPanier extends CartController {
  @override
  Future<Cart?> build() async => _panier();
}

const _bareme = PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 1,
  referrerBonusPoints: 1,
);

String _normalise(String s) => s.replaceAll(RegExp(r'[\s   ]'), ' ');

Widget _barre({
  VoidCallback? onPressed,
  bool isSending = false,
  String? disabledReason,
}) => MaterialApp(
  home: Scaffold(
    body: const SizedBox.expand(),
    bottomNavigationBar: CheckoutSubmitBar(
      total: 24000,
      onPressed: onPressed,
      isSending: isSending,
      disabledReason: disabledReason,
    ),
  ),
);

void main() {
  group('CheckoutSubmitBar', () {
    testWidgets('actif : montre le total et transmet le tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_barre(onPressed: () => taps++));

      final total = tester.widget<Text>(
        find.byKey(const Key('checkout_submit_total')),
      );
      expect(_normalise(total.data!), contains('24 000'));
      await tester.tap(find.byKey(const Key('checkout_submit')));
      expect(taps, 1);
    });

    testWidgets('désactivé : pas de tap, et la raison est dite', (
      tester,
    ) async {
      await tester.pumpWidget(
        _barre(disabledReason: 'Choisissez un créneau pour continuer.'),
      );

      final bouton = tester.widget<ElevatedButton>(
        find.byKey(const Key('checkout_submit')),
      );
      expect(bouton.onPressed, isNull);
      expect(
        find.text('Choisissez un créneau pour continuer.'),
        findsOneWidget,
      );
    });

    testWidgets('envoi : indicateur annoncé, ni libellé ni raison', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _barre(isSending: true, disabledReason: 'Choisissez un créneau.'),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Valider et payer'), findsNothing);
      expect(find.text('Choisissez un créneau.'), findsNothing);
      expect(
        find.bySemanticsLabel('Envoi de la commande en cours'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('au-dessus de la zone de geste (SafeArea)', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(bottom: 68); // 34 dp
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_barre(onPressed: () {}));

      final bas = tester.getBottomLeft(
        find.byKey(const Key('checkout_submit')),
      );
      expect(bas.dy, lessThanOrEqualTo(667 - 34));
      // Et pas davantage : la barre est bien collée au pied (marge 12 dp).
      expect(bas.dy, greaterThan(667 - 34 - 20));
    });
  });

  group('CheckoutPage', () {
    Future<void> monter(WidgetTester tester) async {
      // Petit téléphone (iPhone SE) : le formulaire dépasse l'écran.
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartControllerProvider.overrideWith(_FauxPanier.new),
            restaurantControllerProvider(_restaurantId).overrideWith(
              (ref) async => Restaurant(
                id: _restaurantId,
                name: 'Chez Lilia',
                address: 'Poto-Poto',
                products: const [],
                categoriesMap: const {},
                vendorType: VendorType.RESTAURANT,
              ),
            ),
            userProfileProvider.overrideWith(
              (ref) async => const AppUser(uid: 'uid-a', phone: '060000000'),
            ),
            platformSettingsProvider.overrideWith((ref) async => _bareme),
          ],
          child: MaterialApp(
            home: CheckoutPage(
              deliveryOptions: DeliveryOptions(
                isDelivery: true,
                quartier: null,
                address: null,
                newAddressRue: null,
                newAddressLocation: null,
                deliveryFee: 1000,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    bool visible(WidgetTester tester, Finder f) {
      final rect = tester.getRect(f);
      return rect.top >= 0 && rect.bottom <= 667;
    }

    testWidgets('le CTA est visible sans défiler, et le reste après', (
      tester,
    ) async {
      await monter(tester);
      final cta = find.byKey(const Key('checkout_submit'));

      expect(cta, findsOneWidget);
      expect(visible(tester, cta), isTrue);
      // Le formulaire, lui, dépasse bien l'écran : sinon le test ne prouve rien.
      expect(
        tester.getRect(find.text('Enregistrer pour plus tard')).top,
        greaterThan(667),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(visible(tester, cta), isTrue);
      final bouton = tester.widget<ElevatedButton>(cta);
      expect(bouton.onPressed, isNotNull);
    });

    testWidgets('la barre affiche le même total que le récapitulatif', (
      tester,
    ) async {
      await monter(tester);
      // 20 000 + 1 000 de livraison + 3 000 de frais (15 %) = 24 000.
      final total = tester.widget<Text>(
        find.byKey(const Key('checkout_submit_total')),
      );
      expect(_normalise(total.data!), contains('24 000'));
    });
  });
}
