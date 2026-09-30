// P3-16 — une commande en attente de paiement montre son action principale
// (payer, ou « paiement en cours ») AVANT le récapitulatif ; les autres
// statuts n'affichent aucune section de paiement. Monte la vraie page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/presentation/commande_detail_page.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/order_detail_cards.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/services/notification_router.dart';

import '../../helpers/real_fonts.dart';

const _id = 'o-1';

Order _commande(String status) => Order.fromJson({
  'id': _id,
  'status': status,
  'isDelivery': true,
  'subTotal': 20000,
  'deliveryFee': 1000,
  'serviceFee': 3000,
  'total': 24000,
  'paymentMethod': 'MTN_MOMO',
  'deliveryAddress': 'Rue Mbochis, Poto-Poto',
  'createdAt': '2026-09-29T11:00:00.000Z',
  'updatedAt': '2026-09-29T11:00:00.000Z',
  'restaurant': {'nom': 'Chez Awa', 'adresse': 'Av. de la Paix'},
  'items': <dynamic>[],
});

class _Liste extends UserOrders {
  @override
  Future<List<Order>> build() async => const [];
}

Future<void> _monter(
  WidgetTester tester, {
  required String status,
  PaymentStatus? paiement,
  bool intentionRelance = false,
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        orderDetailProvider(_id).overrideWith((ref) async => _commande(status)),
        userOrdersProvider.overrideWith(_Liste.new),
        orderPaymentProvider(_id).overrideWith(
          (ref) async => paiement == null
              ? null
              : PaymentStatusResponse(paymentId: 'p-1', status: paiement),
        ),
        if (intentionRelance)
          pendingNotificationIntentProvider.overrideWith(
            (ref) => (orderId: _id, intent: NotificationIntent.retryPayment),
          ),
      ],
      child: const MaterialApp(home: OrderDetailPage(orderId: _id)),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

double _haut(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    // La police carrée de `flutter_test` fabrique des débordements qui
    // n'existent pas sur l'appareil.
    await chargerPolicesReelles();
  });

  testWidgets('EN_ATTENTE : « Payer maintenant » avant articles et total', (
    tester,
  ) async {
    await _monter(tester, status: 'EN_ATTENTE');

    final payer = find.textContaining('Payer maintenant');
    expect(payer, findsOneWidget);
    expect(
      _haut(tester, payer),
      lessThan(_haut(tester, find.byType(OrderItemsCard))),
    );
    expect(
      _haut(tester, payer),
      lessThan(_haut(tester, find.byType(OrderSummaryCard))),
    );
    // L'en-tête reste en tête : on sait de quelle commande on parle.
    expect(
      _haut(tester, find.byType(OrderHeaderCard)),
      lessThan(_haut(tester, payer)),
    );
  });

  testWidgets('EN_ATTENTE, paiement en cours : l’info passe avant le total', (
    tester,
  ) async {
    await _monter(
      tester,
      status: 'EN_ATTENTE',
      paiement: PaymentStatus.pending,
    );

    final enCours = find.text('Paiement en cours');
    expect(enCours, findsOneWidget);
    expect(find.textContaining('Payer maintenant'), findsNothing);
    expect(
      _haut(tester, enCours),
      lessThan(_haut(tester, find.byType(OrderSummaryCard))),
    );
  });

  testWidgets(
    'relance après échec : la bannière suit le bouton « ci-dessus »',
    (tester) async {
      await _monter(tester, status: 'EN_ATTENTE', intentionRelance: true);

      final banniere = find.textContaining('Le paiement n\'a pas abouti');
      expect(banniere, findsOneWidget);
      final payer = find.textContaining('Payer maintenant');
      expect(_haut(tester, payer), lessThan(_haut(tester, banniere)));
      expect(
        _haut(tester, banniere),
        lessThan(_haut(tester, find.byType(OrderItemsCard))),
      );
    },
  );

  for (final status in [
    'PAYER',
    'EN_PREPARATION',
    'PRET',
    'LIVRER',
    'ANNULER',
  ]) {
    testWidgets('$status : aucune section de paiement', (tester) async {
      await _monter(tester, status: status);

      expect(find.textContaining('Payer maintenant'), findsNothing);
      expect(find.text('Paiement en cours'), findsNothing);
      expect(find.byType(OrderSummaryCard), findsOneWidget);
    });
  }
}
