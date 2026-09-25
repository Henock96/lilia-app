import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/commandes/presentation/commande_detail_page.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/pickup_card.dart';
import 'package:lilia_app/models/order.dart';

/// Retrait au comptoir (F3-07) : le code à montrer et « J'ai récupéré ma
/// commande ». Le bouton suit `allowedActions` — jamais le statut seul.
Order _order({
  String status = 'PRET',
  bool isDelivery = false,
  String? pickupCode,
  String? deliveryProof,
  List<String>? allowedActions,
}) => Order.fromJson({
  'id': 'o-1',
  'status': status,
  'isDelivery': isDelivery,
  'total': 4000,
  'createdAt': '2026-09-25T11:00:00.000Z',
  'updatedAt': '2026-09-25T11:00:00.000Z',
  'restaurant': {'nom': 'Chez Awa'},
  'items': <dynamic>[],
  'pickupCode': ?pickupCode,
  'deliveryProof': ?deliveryProof,
  'allowedActions': ?allowedActions,
});

final _ready = _order(pickupCode: '4821', allowedActions: ['CONFIRM_PICKUP']);
final _confirmed = _order(
  status: 'LIVRER',
  deliveryProof: 'PICKUP_CUSTOMER_CONFIRMED',
  allowedActions: [],
);

void main() {
  group('modèle', () {
    test('lit le code, la preuve et la date de confirmation', () {
      final order = Order.fromJson({
        'id': 'o-1',
        'status': 'LIVRER',
        'isDelivery': false,
        'restaurant': <String, dynamic>{},
        'pickupCode': '0472',
        'deliveryProof': 'PICKUP_CUSTOMER_CONFIRMED',
        'customerConfirmedAt': '2026-09-25T12:00:00.000Z',
      });
      expect(order.pickupCode, '0472');
      expect(order.deliveryProof, 'PICKUP_CUSTOMER_CONFIRMED');
      expect(order.customerConfirmedAt, DateTime.utc(2026, 9, 25, 12));
    });

    test('un serveur antérieur (champs absents) ne casse rien', () {
      final order = _order();
      expect(order.pickupCode, isNull);
      expect(order.deliveryProof, isNull);
      expect(order.canConfirmPickup, isFalse);
    });

    test('remise déclarée par le vendeur seul : pas encore « prouvée »', () {
      expect(
        _order(status: 'LIVRER', deliveryProof: 'PICKUP_VENDOR_DECLARED')
            .pickupProved,
        isFalse,
      );
      expect(_confirmed.pickupProved, isTrue);
      expect(
        _order(status: 'LIVRER', deliveryProof: 'PICKUP_CODE').pickupProved,
        isTrue,
      );
    });
  });

  group('quand la carte apparaît', () {
    test('jamais pour une livraison à domicile', () {
      expect(
        PickupCard.isRelevant(
          _order(
            isDelivery: true,
            pickupCode: '4821',
            allowedActions: ['CONFIRM_PICKUP'],
          ),
        ),
        isFalse,
      );
    });

    test('jamais avant que la commande soit prête', () {
      for (final status in ['EN_ATTENTE', 'PAYER', 'EN_PREPARATION']) {
        expect(PickupCard.isRelevant(_order(status: status)), isFalse);
      }
    });

    test('ni sur une commande annulée', () {
      expect(PickupCard.isRelevant(_order(status: 'ANNULER')), isFalse);
    });

    test('prête, avec code ou bouton : oui', () {
      expect(PickupCard.isRelevant(_ready), isTrue);
    });
  });

  group('PickupCard', () {
    late List<Completer<Order>> calls;
    late List<Order> confirmed;

    Future<void> pump(WidgetTester tester, Order order) async {
      calls = [];
      confirmed = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PickupCard(
                order: order,
                onConfirm: () {
                  final c = Completer<Order>();
                  calls.add(c);
                  return c.future;
                },
                onConfirmed: confirmed.add,
              ),
            ),
          ),
        ),
      );
    }

    Future<void> tapAndAccept(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('pickup-confirm-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickup-confirm-dialog-yes')));
      await tester.pump();
    }

    testWidgets('affiche le code en grand et le bouton', (tester) async {
      await pump(tester, _ready);
      expect(find.byKey(const Key('pickup-code')), findsOneWidget);
      expect(find.text('4821'), findsOneWidget);
      expect(find.text('J’ai récupéré ma commande'), findsOneWidget);
    });

    testWidgets('pas de bouton si le serveur ne le propose pas', (tester) async {
      await pump(tester, _order(pickupCode: '4821', allowedActions: []));
      expect(find.byKey(const Key('pickup-confirm-button')), findsNothing);
      expect(find.byKey(const Key('pickup-code')), findsOneWidget);
    });

    testWidgets('« Pas encore » n’envoie rien', (tester) async {
      await pump(tester, _ready);
      await tester.tap(find.byKey(const Key('pickup-confirm-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pas encore'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('pendant l’envoi : chargement, bouton désactivé, un seul appel', (
      tester,
    ) async {
      await pump(tester, _ready);
      await tapAndAccept(tester);

      expect(calls, hasLength(1));
      expect(find.text('Confirmation…'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('pickup-confirm-button')),
      );
      expect(button.onPressed, isNull);

      // Double tap : le bouton désactivé ne relance rien.
      await tester.tap(
        find.byKey(const Key('pickup-confirm-button')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(calls, hasLength(1));

      calls.single.complete(_confirmed);
      await tester.pump();
      expect(confirmed, [_confirmed]);
    });

    testWidgets('erreur réseau : message affiché, bouton de nouveau actif', (
      tester,
    ) async {
      await pump(tester, _ready);
      await tapAndAccept(tester);
      calls.single.completeError(
        const ApiException(
          'Connexion impossible. Vérifiez votre réseau.',
          kind: ApiErrorKind.network,
        ),
      );
      await tester.pump();

      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );
      expect(confirmed, isEmpty);
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('pickup-confirm-button')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('après confirmation : plus de bouton, « Commande récupérée »', (
      tester,
    ) async {
      await pump(tester, _confirmed);
      expect(find.byKey(const Key('pickup-confirm-button')), findsNothing);
      expect(find.text('Commande récupérée'), findsOneWidget);
    });

    testWidgets('remise déclarée par le vendeur : le client peut confirmer', (
      tester,
    ) async {
      await pump(
        tester,
        _order(
          status: 'LIVRER',
          deliveryProof: 'PICKUP_VENDOR_DECLARED',
          allowedActions: ['CONFIRM_PICKUP'],
        ),
      );
      expect(
        find.text('Le restaurant indique vous avoir remis votre commande.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pickup-confirm-button')), findsOneWidget);
      // Le code ne s'affiche plus une fois la commande remise.
      expect(find.byKey(const Key('pickup-code')), findsNothing);
    });
  });

  group('en-tête d’un retrait', () {
    test('« prête » parle du restaurant, pas de livraison', () {
      expect(
        pickupStatusInfo(_ready)!.description,
        'Votre commande vous attend au restaurant',
      );
    });

    test('jamais « Livrée » pour un retrait', () {
      expect(pickupStatusInfo(_confirmed)!.label, 'Récupérée');
      expect(
        pickupStatusInfo(
          _order(status: 'LIVRER', deliveryProof: 'PICKUP_VENDOR_DECLARED'),
        )!.label,
        'Remise',
      );
    });

    test('une livraison garde les libellés habituels', () {
      expect(pickupStatusInfo(_order(isDelivery: true)), isNull);
    });
  });
}
