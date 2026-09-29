// Le récapitulatif du checkout, extrait de `CheckoutPage` : il affiche les
// montants reçus, sans en recalculer aucun, et ses remises sont lisibles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/checkout_order_summary.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/promo_validation_result.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';

Cart _panier() => Cart(
  id: 'panier-1',
  userId: 'uid-a',
  createdAt: DateTime(2026, 9, 20),
  updatedAt: DateTime(2026, 9, 20),
  items: [
    CartItem(
      id: 'ligne-1',
      cartId: 'panier-1',
      productId: 'prod-1',
      variantId: 'var-1',
      quantite: 2,
      createdAt: DateTime(2026, 9, 20),
      product: ProductItem(nom: 'Poulet braisé', restaurantId: 'resto-1'),
      variant: VariantItem(label: 'Entier', prix: 10000),
    ),
  ],
);

PromoValidationResult _promo(DiscountType type, double montant) =>
    PromoValidationResult(
      valid: true,
      promoCodeId: 'promo-1',
      code: 'BIENVENUE',
      discountType: type,
      discountAmount: montant,
      newTotal: 0,
      newDeliveryFee: 0,
    );

Future<void> _monter(
  WidgetTester tester,
  CheckoutOrderSummary resume, {
  ThemeData? theme,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: resume)),
  ),
);

CheckoutOrderSummary _resume({
  bool isDelivery = true,
  double deliveryFee = 1000,
  double originalDeliveryFee = 1000,
  double deliverySubsidy = 0,
  PromoValidationResult? promo,
  double loyaltyDiscount = 0,
  double total = 24000,
}) => CheckoutOrderSummary(
  cart: _panier(),
  isDelivery: isDelivery,
  subTotal: 20000,
  deliveryFee: deliveryFee,
  originalDeliveryFee: originalDeliveryFee,
  deliverySubsidy: deliverySubsidy,
  serviceFee: 3000,
  promo: promo,
  loyaltyDiscount: loyaltyDiscount,
  total: total,
);

void main() {
  testWidgets('affiche les montants reçus, tels quels', (tester) async {
    await _monter(tester, _resume());
    expect(find.text('2x Poulet braisé'), findsOneWidget);
    expect(find.text(formatPrice(20000)), findsNWidgets(2)); // ligne + sous-total
    expect(find.text(formatPrice(1000)), findsOneWidget);
    expect(find.text(formatPrice(3000)), findsOneWidget);
    // Le total est celui fourni, pas une somme refaite ici.
    expect(find.text(formatPrice(24000)), findsOneWidget);
    expect(find.text('Points fidélité'), findsNothing);
    expect(find.textContaining('Promo'), findsNothing);
  });

  testWidgets('retrait : livraison « Gratuit »', (tester) async {
    await _monter(tester, _resume(isDelivery: false, deliveryFee: 0));
    expect(find.text('Gratuit'), findsOneWidget);
  });

  testWidgets('promo livraison offerte : ancien prix barré', (tester) async {
    await _monter(
      tester,
      _resume(
        deliveryFee: 0,
        originalDeliveryFee: 1500,
        promo: _promo(DiscountType.freeDelivery, 1500),
      ),
    );
    final barre = tester.widget<Text>(find.text(formatPrice(1500)));
    expect(barre.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Promo BIENVENUE'), findsOneWidget);
  });

  testWidgets('part vendeur (F3-02) : base barrée, « Offerte » si tout payé', (
    tester,
  ) async {
    await _monter(tester, _resume(deliveryFee: 0, deliverySubsidy: 1000));
    expect(find.text('Offerte'), findsOneWidget);
    expect(find.text(formatPrice(1000)), findsOneWidget);
  });

  testWidgets(
    'remises promo et fidélité en couleurs de texte lisibles, clair et sombre',
    (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await _monter(
          tester,
          _resume(promo: _promo(DiscountType.fixed, 500), loyaltyDiscount: 750),
          theme: theme,
        );
        await tester.pumpAndSettle();

        final promo = tester.widget<Text>(find.text('- ${formatPrice(500)}'));
        final points = tester.widget<Text>(find.text('- ${formatPrice(750)}'));
        // Et non `Colors.green` / `Colors.amber` : 2.3:1 et 1.35:1 sur
        // `surfaceContainerHighest` en clair.
        expect(promo.style?.color, theme.colorScheme.successText);
        expect(points.style?.color, theme.colorScheme.warningText);
      }
    },
  );
}
