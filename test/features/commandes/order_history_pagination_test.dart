// Faux contrôleurs de test : ils exposent volontairement des compteurs pour
// les assertions (`avoid_public_notifier_properties` vise le code de prod).
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties
// **« Absente de la page 1 » n'est pas « inexistante ».**
//
// `GET /orders/my` rend vingt commandes par défaut, le client n'en demandait
// jamais la suite, et `OrderDetailPage` cherchait sa commande **dans cette
// liste**. Un client à vingt-cinq commandes perdait donc son historique, ses
// reçus, et voyait « Cette commande n'est plus disponible » sur une commande
// parfaitement vivante côté serveur.
//
// `GET /orders/:id` existait depuis toujours, sans aucun appelant.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/features/commandes/presentation/commande_detail_page.dart';
import 'package:lilia_app/models/order.dart';

/// 25 commandes, comme un client fidèle en a.
const _total = 25;

Order _commande(int n) => Order(
      id: 'cmd-$n',
      restaurantId: 'resto-1',
      userId: 'uid-a',
      subTotal: 5000,
      deliveryFee: 1000,
      total: 6750,
      paymentMethod: 'MTN_MOMO',
      status: OrderStatus.livrer,
      createdAt: DateTime(2026, 9, 20).subtract(Duration(days: n)),
      updatedAt: DateTime(2026, 9, 20),
      restaurant: OrderRestaurant(nom: 'Chez Lilia'),
      items: const [],
    );

/// Dépôt paginé fidèle au serveur : `limit = 20`, `meta.totalPages` calculé.
class _FauxDepot extends OrderRepository {
  final List<String> pagesDemandees = [];
  final List<String> detailsDemandes = [];
  int echecsAvantSucces = 0;

  @override
  Future<void> build() async {}

  @override
  Future<OrdersPage> getMyOrders({int page = 1}) async {
    pagesDemandees.add('p$page');
    if (echecsAvantSucces > 0) {
      echecsAvantSucces--;
      throw Exception('réseau');
    }
    const taille = OrderRepository.pageSize;
    final debut = (page - 1) * taille;
    final fin = (debut + taille).clamp(0, _total);
    return OrdersPage(
      orders: [
        for (var i = debut; i < fin; i++) _commande(i + 1),
      ],
      page: page,
      totalPages: (_total / taille).ceil(),
    );
  }

  @override
  Future<Order> getOrder(String orderId) async {
    detailsDemandes.add(orderId);
    final n = int.parse(orderId.split('-').last);
    if (n > _total) throw Exception('404');
    return _commande(n);
  }
}

void main() {
  late _FauxDepot depot;
  late ProviderContainer container;

  ProviderContainer monter() {
    depot = _FauxDepot();
    container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWith(() => depot)],
    );
    addTearDown(container.dispose);
    addTearDown(container.listen(userOrdersProvider, (_, _) {}).close);
    return container;
  }

  group('pagination de l’historique', () {
    test('la première page demande explicitement page=1 et limit=20', () async {
      monter();
      final premiere = await container.read(userOrdersProvider.future);

      expect(premiere, hasLength(20));
      expect(depot.pagesDemandees, ['p1']);
      expect(
        container.read(userOrdersProvider.notifier).hasMore,
        isTrue,
        reason: '25 commandes pour 20 par page : il reste une page',
      );
    });

    test('chargerPlus ajoute la page 2 — les 25 sont accessibles', () async {
      monter();
      await container.read(userOrdersProvider.future);

      await container.read(userOrdersProvider.notifier).chargerPlus();

      final liste = container.read(userOrdersProvider).value!;
      expect(liste, hasLength(_total));
      expect(liste.map((o) => o.id), contains('cmd-21'));
      expect(liste.map((o) => o.id), contains('cmd-25'));
      expect(depot.pagesDemandees, ['p1', 'p2']);
    });

    test('plus rien à charger une fois la dernière page atteinte', () async {
      monter();
      await container.read(userOrdersProvider.future);
      final notifier = container.read(userOrdersProvider.notifier);

      await notifier.chargerPlus();
      expect(notifier.hasMore, isFalse);

      await notifier.chargerPlus();
      expect(
        depot.pagesDemandees,
        ['p1', 'p2'],
        reason: 'un défilement en bout de liste ne doit rien redemander',
      );
    });

    test('deux appels CONCURRENTS ne chargent la page qu’une fois', () async {
      monter();
      await container.read(userOrdersProvider.future);
      final notifier = container.read(userOrdersProvider.notifier);

      // Le cas réel : un défilement émet plusieurs notifications par seconde.
      await Future.wait([notifier.chargerPlus(), notifier.chargerPlus()]);

      expect(depot.pagesDemandees, ['p1', 'p2']);
      expect(container.read(userOrdersProvider).value, hasLength(_total));
    });

    test('aucun doublon si une page en recoupe une autre', () async {
      monter();
      await container.read(userOrdersProvider.future);
      final notifier = container.read(userOrdersProvider.notifier);

      await notifier.chargerPlus();

      final ids = container.read(userOrdersProvider).value!.map((o) => o.id);
      expect(
        ids.toSet(),
        hasLength(_total),
        reason:
            'une commande créée entre deux pages décale la pagination et '
            'ferait réapparaître une ligne déjà reçue',
      );
    });

    test('une page suivante en échec ne vide pas la liste déjà affichée', () async {
      monter();
      await container.read(userOrdersProvider.future);
      final notifier = container.read(userOrdersProvider.notifier);
      depot.echecsAvantSucces = 1;

      await notifier.chargerPlus();

      expect(container.read(userOrdersProvider).value, hasLength(20));
      expect(notifier.hasMore, isTrue, reason: 'la page reste à charger');

      // Et un nouvel essai aboutit : le compteur n'a pas avancé.
      await notifier.chargerPlus();
      expect(container.read(userOrdersProvider).value, hasLength(_total));
    });
  });

  group('détail d’une commande', () {
    testWidgets('une commande HORS de la première page s’affiche', (
      tester,
    ) async {
      depot = _FauxDepot();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [orderRepositoryProvider.overrideWith(() => depot)],
          child: const MaterialApp(
            home: OrderDetailPage(orderId: 'cmd-23'),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        tester.takeException();
      }

      expect(
        depot.detailsDemandes,
        contains('cmd-23'),
        reason: 'l’écran doit interroger GET /orders/:id, pas filtrer la liste',
      );
      expect(
        find.text('Commande introuvable'),
        findsNothing,
        reason:
            'la commande 23 existe : elle n’est simplement pas dans les vingt '
            'dernières',
      );
    });

    testWidgets('une commande réellement absente le dit, avec un Réessayer', (
      tester,
    ) async {
      depot = _FauxDepot();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [orderRepositoryProvider.overrideWith(() => depot)],
          child: const MaterialApp(
            home: OrderDetailPage(orderId: 'cmd-999'),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        tester.takeException();
      }

      expect(find.text('Commande introuvable'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
