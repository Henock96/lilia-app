// P3-09 / P3.1.7 — timeline par mode et ETA.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/domain/order_timeline.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/order_timeline_view.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/theme/app_theme.dart';

Order _commande(OrderStatus status, {bool isDelivery = true}) => Order(
  id: 'cmd-1',
  restaurantId: 'resto-1',
  userId: 'uid-a',
  subTotal: 5000,
  deliveryFee: 1000,
  total: 6750,
  paymentMethod: 'MTN_MOMO',
  status: status,
  isDelivery: isDelivery,
  createdAt: DateTime(2026, 9, 29),
  updatedAt: DateTime(2026, 9, 29),
  restaurant: OrderRestaurant(nom: 'Chez Lilia'),
  items: const [],
);

String? _enCours(List<TimelineStep> steps) => steps
    .where((s) => s.state == TimelineStepState.current)
    .map((s) => s.label)
    .firstOrNull;

void main() {
  group('livraison', () {
    final attendu = {
      OrderStatus.enAttente: 'Paiement',
      OrderStatus.payer: 'Confirmation du vendeur',
      OrderStatus.acceptee: 'Préparation',
      OrderStatus.enPreparation: 'Préparation',
      OrderStatus.pret: 'Commande prête',
      OrderStatus.enRoute: 'Livreur en route',
    };
    attendu.forEach((status, etape) {
      test('$status → « $etape » en cours', () {
        expect(_enCours(orderTimeline(_commande(status))), etape);
      });
    });

    test('EN_ATTENTE : rien n\'est « confirmé »', () {
      final steps = orderTimeline(_commande(OrderStatus.enAttente));
      expect(steps.first.detail, contains('paiement'));
      expect(steps.where((s) => s.state == TimelineStepState.done), isEmpty);
    });

    test('LIVRER : tout est terminé, dernière étape « Livrée »', () {
      final steps = orderTimeline(_commande(OrderStatus.livrer));
      expect(steps.last.label, 'Livrée');
      expect(steps.every((s) => s.state == TimelineStepState.done), isTrue);
    });
  });

  group('retrait', () {
    final attendu = {
      OrderStatus.enAttente: 'Paiement',
      OrderStatus.payer: 'Confirmation du vendeur',
      OrderStatus.acceptee: 'Préparation',
      OrderStatus.enPreparation: 'Préparation',
      OrderStatus.pret: 'Prête à récupérer',
    };
    attendu.forEach((status, etape) {
      test('$status → « $etape » en cours', () {
        expect(
          _enCours(orderTimeline(_commande(status, isDelivery: false))),
          etape,
        );
      });
    });

    test('jamais « Livreur en route » ni « Livrée »', () {
      for (final status in OrderStatus.values) {
        final labels = orderTimeline(
          _commande(status, isDelivery: false),
        ).map((s) => s.label);
        expect(labels, isNot(contains('Livreur en route')));
        expect(labels, isNot(contains('Livrée')));
      }
    });

    test('LIVRER : « Récupérée » terminée', () {
      final steps = orderTimeline(
        _commande(OrderStatus.livrer, isDelivery: false),
      );
      expect(steps.last.label, 'Récupérée');
      expect(steps.last.state, TimelineStepState.done);
    });
  });

  test('annulée, échec, inconnu : pas de progression inventée', () {
    for (final s in [
      OrderStatus.annuler,
      OrderStatus.echecLivraison,
      OrderStatus.unknow,
    ]) {
      expect(orderTimeline(_commande(s)), isEmpty);
      expect(orderTimeline(_commande(s, isDelivery: false)), isEmpty);
    }
  });

  testWidgets('la vue annonce chaque étape avec son état', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: OrderTimelineView(
            order: _commande(OrderStatus.pret, isDelivery: false),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(
        'Prête à récupérer, en cours, Vous pouvez venir la récupérer',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Paiement, terminée'), findsOneWidget);
    expect(find.bySemanticsLabel('Récupérée, à venir'), findsOneWidget);
  });

  group('etaLine', () {
    final now = DateTime(2026, 9, 29, 12);

    test('pas en route : rien', () {
      expect(
        etaLine(onTheWay: false, etaMinutes: 12, positionAt: now, now: now),
        isNull,
      );
    });

    test('position fraîche : durée « environ », décomptée', () {
      expect(
        etaLine(
          onTheWay: true,
          etaMinutes: 12,
          positionAt: now.subtract(const Duration(minutes: 2)),
          now: now,
        ),
        'Arrivée estimée : environ 10 min',
      );
    });

    test('0 = destination inconnue côté serveur, pas « arrivé »', () {
      expect(
        etaLine(onTheWay: true, etaMinutes: 0, positionAt: now, now: now),
        'Heure d\'arrivée pas encore estimée',
      );
    });

    test('null, négatif ou aberrant : phrase de remplacement', () {
      for (final eta in [null, -3, 999]) {
        expect(
          etaLine(onTheWay: true, etaMinutes: eta, positionAt: now, now: now),
          'Heure d\'arrivée pas encore estimée',
        );
      }
    });

    test('position périmée : pas de chiffre', () {
      expect(
        etaLine(
          onTheWay: true,
          etaMinutes: 12,
          positionAt: now.subtract(const Duration(minutes: 9)),
          now: now,
        ),
        contains('position récente'),
      );
    });
  });
}
