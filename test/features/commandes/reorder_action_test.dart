// P3-22 — « Commander à nouveau » : geste partagé liste / détail, verdict
// serveur relayé (articles écartés nommés), jamais d'erreur brute.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/presentation/order_progress_bar.dart';
import 'package:lilia_app/features/commandes/presentation/reorder_action.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/theme/app_theme.dart';

class _Panier extends CartController {
  _Panier(this.reponse);
  final Object reponse;
  final demandes = <String>[];

  @override
  Future<Cart?> build() async => null;

  @override
  Future<Map<String, dynamic>> reorder({required String orderId}) async {
    demandes.add(orderId);
    final r = reponse;
    if (r is Exception) throw r;
    return r as Map<String, dynamic>;
  }
}

Future<_Panier> _monter(WidgetTester tester, Object reponse) async {
  final panier = _Panier(reponse);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [cartControllerProvider.overrideWith(() => panier)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => reorderIntoCart(context, ref, 'cmd-7'),
              child: const Text('Commander à nouveau'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Commander à nouveau'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return panier;
}

Order _commande(OrderStatus s, {bool livraison = true}) => Order(
  id: 'cmd-7',
  restaurantId: 'r',
  userId: 'u',
  subTotal: 5000,
  deliveryFee: 1000,
  total: 6750,
  paymentMethod: 'MTN_MOMO',
  status: s,
  isDelivery: livraison,
  createdAt: DateTime(2026, 9, 29),
  updatedAt: DateTime(2026, 9, 29),
  restaurant: OrderRestaurant(nom: 'Chez Awa'),
  items: const [],
);

void main() {
  testWidgets('articles écartés : nombre et raisons du serveur', (
    tester,
  ) async {
    final panier = await _monter(tester, {
      'summary': {'totalAdded': 2, 'totalUnavailable': 1},
      'details': {
        'unavailable': [
          {'reason': 'Le format « Entier » n\'est plus proposé.'},
        ],
      },
    });
    expect(panier.demandes, ['cmd-7']);
    expect(find.textContaining('2 articles ajoutés'), findsOneWidget);
    expect(
      find.textContaining('« Entier » n\'est plus proposé'),
      findsOneWidget,
    );
    expect(find.text('Voir le panier'), findsOneWidget);
  });

  testWidgets('refus serveur : son message, jamais « Exception: »', (
    tester,
  ) async {
    await _monter(
      tester,
      const ApiException(
        'Votre panier contient déjà des articles d\'un autre restaurant.',
        statusCode: 400,
        kind: ApiErrorKind.client,
      ),
    );
    expect(find.textContaining('autre restaurant'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  group('OrderProgressBar (liste) — même règle que le détail', () {
    Future<void> barre(WidgetTester t, Order o) => t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: OrderProgressBar(order: o)),
      ),
    );

    testWidgets('en attente de paiement : pas « Confirmée »', (tester) async {
      await barre(tester, _commande(OrderStatus.enAttente));
      expect(find.textContaining('Confirmée'), findsNothing);
      expect(
        find.textContaining('En attente de votre paiement'),
        findsOneWidget,
      );
    });

    testWidgets('retrait prêt : « Prête à récupérer », jamais « En route »', (
      tester,
    ) async {
      await barre(tester, _commande(OrderStatus.pret, livraison: false));
      expect(find.textContaining('Prête à récupérer'), findsOneWidget);
      expect(find.textContaining('route'), findsNothing);
    });
  });
}
