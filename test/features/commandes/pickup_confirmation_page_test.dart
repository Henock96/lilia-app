// Faux dépôt de test : il expose volontairement des compteurs pour les
// assertions (`avoid_public_notifier_properties` vise le code de prod).
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/features/commandes/presentation/commande_detail_page.dart';
import 'package:lilia_app/models/order.dart';

/// « J'ai récupéré ma commande » sur le VRAI écran de détail (F3-07) : la
/// confirmation doit relire la commande — c'est le serveur qui retire le
/// bouton, pas l'écran.
Order _pickup({required bool confirmed}) => Order(
  id: 'cmd-1',
  restaurantId: 'resto-1',
  userId: 'uid-a',
  subTotal: 4000,
  deliveryFee: 0,
  total: 4000,
  paymentMethod: 'MTN_MOMO',
  status: confirmed ? OrderStatus.livrer : OrderStatus.pret,
  createdAt: DateTime(2026, 9, 25, 11),
  updatedAt: DateTime(2026, 9, 25, 11),
  restaurant: OrderRestaurant(nom: 'Chez Lilia'),
  items: const [],
  isDelivery: false,
  pickupCode: confirmed ? null : '4821',
  deliveryProof: confirmed ? 'PICKUP_CUSTOMER_CONFIRMED' : null,
  allowedActions: confirmed ? const [] : const ['CONFIRM_PICKUP'],
);

class _FauxDepot extends OrderRepository {
  bool confirme = false;
  int confirmations = 0;
  int lectures = 0;

  @override
  Future<void> build() async {}

  @override
  Future<OrdersPage> getMyOrders({int page = 1}) async =>
      OrdersPage(orders: const [], page: 1, totalPages: 1);

  @override
  Future<Order> getOrder(String orderId) async {
    lectures++;
    return _pickup(confirmed: confirme);
  }

  @override
  Future<Order> confirmPickup(String orderId) async {
    confirmations++;
    confirme = true;
    return _pickup(confirmed: true);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('confirmer relit la commande : le bouton disparaît', (
    tester,
  ) async {
    final depot = _FauxDepot();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWith(() => depot)],
        child: const MaterialApp(home: OrderDetailPage(orderId: 'cmd-1')),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        // Aucune exception tolérée : un écran qui ne se rend pas ne prouve
        // rien (la locale fr_FR manquante faisait échouer le rendu en
        // silence dans un test voisin).
        expect(tester.takeException(), isNull);
      }
    }

    await settle();
    final button = find.byKey(const Key('pickup-confirm-button'));
    await tester.scrollUntilVisible(button, 200);
    expect(find.text('4821'), findsOneWidget);
    final lecturesAvant = depot.lectures;

    await tester.tap(button);
    await settle();
    await tester.tap(find.byKey(const Key('pickup-confirm-dialog-yes')));
    await settle();

    expect(depot.confirmations, 1);
    expect(
      depot.lectures,
      greaterThan(lecturesAvant),
      reason: 'la commande est relue après la confirmation',
    );
    expect(find.byKey(const Key('pickup-confirm-button')), findsNothing);
    expect(find.text('Commande récupérée'), findsOneWidget);
    expect(find.text('Récupérée'), findsOneWidget);
  });
}
