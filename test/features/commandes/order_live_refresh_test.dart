// La fiche commande se relit seule tant que la commande vit.
//
// Constaté le 22/11/2026 (démo) : sans notification, la fiche restait figée —
// acceptation, paiement, départ du livreur n'apparaissaient qu'en tirant
// l'écran. Sur iPhone, où les push n'arrivent pas encore, c'était le seul
// moyen de voir la commande avancer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/order_live_refresh.dart';
import 'package:lilia_app/models/order.dart';

Order _commande(OrderStatus status) => Order(
  id: 'cmd-1',
  restaurantId: 'resto-1',
  userId: 'uid-a',
  subTotal: 5000,
  deliveryFee: 1000,
  total: 6750,
  paymentMethod: 'MTN_MOMO',
  status: status,
  isDelivery: true,
  createdAt: DateTime(2026, 11, 22),
  updatedAt: DateTime(2026, 11, 22),
  restaurant: OrderRestaurant(nom: 'Chez Lilia'),
  items: const [],
);

Future<int> _lectures(WidgetTester tester, OrderStatus status) async {
  var lectures = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderDetailProvider('cmd-1').overrideWith((ref) async {
          lectures++;
          return _commande(status);
        }),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            final order = ref.watch(orderDetailProvider('cmd-1')).value;
            return order == null
                ? const SizedBox()
                : OrderLiveRefresh(
                    orderId: order.id,
                    status: order.status,
                    interval: const Duration(milliseconds: 100),
                  );
          },
        ),
      ),
    ),
  );
  for (var i = 0; i < 7; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpWidget(const SizedBox());
  return lectures;
}

void main() {
  test('vit tant que la commande n’est pas terminée', () {
    for (final s in [
      OrderStatus.demandeEnvoyee,
      OrderStatus.enAttente,
      OrderStatus.payer,
      OrderStatus.enPreparation,
      OrderStatus.pret,
      OrderStatus.enRoute,
    ]) {
      expect(orderNeedsLiveRefresh(s), isTrue, reason: '$s');
    }
    for (final s in [
      OrderStatus.livrer,
      OrderStatus.annuler,
      OrderStatus.echecLivraison,
      OrderStatus.unknow,
    ]) {
      expect(orderNeedsLiveRefresh(s), isFalse, reason: '$s');
    }
  });

  testWidgets('commande en cours : relue à chaque intervalle', (tester) async {
    expect(await _lectures(tester, OrderStatus.pret), greaterThanOrEqualTo(3));
  });

  testWidgets('commande livrée : plus aucune relecture', (tester) async {
    expect(await _lectures(tester, OrderStatus.livrer), 1);
  });
}
