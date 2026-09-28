// Cartes d'affichage extraites du détail de commande : elles se rendent
// seules (sans provider), dans les deux thèmes, avec des contrastes AA.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/order_detail_cards.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:lilia_app/utils/currency.dart';

Order _commande() => Order.fromJson({
  'id': 'o-1',
  'status': 'EN_PREPARATION',
  'isDelivery': true,
  'subTotal': 20000,
  'deliveryFee': 1000,
  'serviceFee': 3000,
  'discountAmount': 500,
  'total': 23500,
  'paymentMethod': 'MTN_MOMO',
  'deliveryAddress': 'Rue Mbochis, Poto-Poto',
  'deliveryLandmark': 'Face à la pharmacie',
  'deliveryPrecision': 'APPROXIMATE',
  'createdAt': '2026-09-25T11:00:00.000Z',
  'updatedAt': '2026-09-25T11:00:00.000Z',
  'restaurant': {'nom': 'Chez Awa', 'adresse': 'Av. de la Paix'},
  'items': <dynamic>[],
});

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('cartes du détail — ${theme.brightness.name}', (tester) async {
      final order = _commande();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ListView(
              children: [
                OrderHeaderCard(order: order),
                OrderVendorCard(order: order),
                OrderItemsCard(order: order),
                OrderDeliveryCard(order: order),
                OrderSummaryCard(order: order),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('En préparation'), findsWidgets);
      expect(find.text('Chez Awa'), findsOneWidget);
      expect(find.text('Repère : Face à la pharmacie'), findsOneWidget);
      expect(find.textContaining('Position au quartier'), findsOneWidget);
      expect(find.text(formatPrice(23500)), findsOneWidget);
      expect(find.text('Réduction'), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
