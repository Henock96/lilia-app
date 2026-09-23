import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/domain/order_status_view.dart';
import 'package:lilia_app/models/order.dart';

/// Ce que le client voit de l'acceptation vendeur (Phase 3, F3-01).
///
/// Une commande payée que le vendeur refuse, ou laisse sans réponse, est
/// annulée et REMBOURSÉE automatiquement : le client doit le lire. Mêmes
/// règles que le site (`apps/web/lib/order-status-view.ts`).
Order _order({
  String status = 'PAYER',
  String? paidAt,
  String? estimatedReadyAt,
  String? vendorRejectionReason,
  Object? allowedActions,
}) =>
    Order.fromJson({
      'id': 'o-1',
      'status': status,
      'total': 6750,
      'createdAt': '2026-09-24T11:00:00.000Z',
      'updatedAt': '2026-09-24T11:00:00.000Z',
      'restaurant': {'nom': 'Chez Awa'},
      'items': <dynamic>[],
      'paidAt': ?paidAt,
      'estimatedReadyAt': ?estimatedReadyAt,
      'vendorRejectionReason': ?vendorRejectionReason,
      'allowedActions': ?allowedActions,
    });

void main() {
  group('modèle', () {
    test('ACCEPTEE et ECHEC_LIVRAISON ne tombent plus en « inconnu »', () {
      expect(_order(status: 'ACCEPTEE').status, OrderStatus.acceptee);
      expect(_order(status: 'ECHEC_LIVRAISON').status, OrderStatus.echecLivraison);
    });

    test('lit paiement, heure de fin annoncée, motif et gestes publiés', () {
      final order = _order(
        paidAt: '2026-09-24T11:00:00.000Z',
        estimatedReadyAt: '2026-09-24T11:40:00.000Z',
        vendorRejectionReason: 'TOO_BUSY',
        allowedActions: ['CANCEL'],
      );
      expect(order.paidAt, DateTime.utc(2026, 9, 24, 11));
      expect(order.estimatedReadyAt, DateTime.utc(2026, 9, 24, 11, 40));
      expect(order.vendorRejectionReason, 'TOO_BUSY');
      expect(order.allowedActions, ['CANCEL']);
    });

    test('gestes absents (serveur antérieur) : null, pas une liste vide', () {
      expect(_order().allowedActions, isNull);
    });
  });

  group('acceptanceLine', () {
    test('payée, pas encore acceptée : on attend le vendeur', () {
      expect(acceptanceLine(_order(status: 'PAYER')), 'En attente de la réponse du vendeur');
    });

    test('acceptée : heure de fin à l’heure de Brazzaville', () {
      expect(
        acceptanceLine(
          _order(status: 'ACCEPTEE', estimatedReadyAt: '2026-09-24T11:40:00.000Z'),
        ),
        'Acceptée par le vendeur · prête vers 12:40',
      );
    });

    test('en préparation avec heure annoncée : l’heure reste utile', () {
      expect(
        acceptanceLine(
          _order(status: 'EN_PREPARATION', estimatedReadyAt: '2026-09-24T11:40:00.000Z'),
        ),
        'Prête vers 12:40',
      );
    });

    test('rien à dire sinon', () {
      expect(acceptanceLine(_order(status: 'EN_ATTENTE')), isNull);
      expect(acceptanceLine(_order(status: 'EN_PREPARATION')), isNull);
      expect(acceptanceLine(_order(status: 'LIVRER')), isNull);
    });
  });

  group('cancellationNotice', () {
    test('jamais payée : rien n’a été débité', () {
      final n = cancellationNotice(_order(status: 'ANNULER'));
      expect(n.title, 'Commande annulée');
      expect(n.detail, contains('Aucun montant'));
    });

    test('payée puis refusée : motif et remboursement', () {
      final n = cancellationNotice(
        _order(
          status: 'ANNULER',
          paidAt: '2026-09-24T11:00:00.000Z',
          vendorRejectionReason: 'OUT_OF_STOCK',
        ),
      );
      expect(n.title, 'Chez Awa n’a pas pu prendre votre commande');
      expect(n.detail, contains('rupture de stock'));
      expect(n.detail, contains('remboursement'));
    });

    test('payée puis restée sans réponse : remboursement annoncé', () {
      final n = cancellationNotice(
        _order(status: 'ANNULER', paidAt: '2026-09-24T11:00:00.000Z'),
      );
      expect(n.detail, contains('remboursement'));
    });
  });

  group('canClientCancel', () {
    test('le serveur fait foi quand il publie', () {
      expect(canClientCancel(_order(status: 'EN_ATTENTE', allowedActions: <String>[])), isFalse);
      expect(canClientCancel(_order(status: 'EN_ATTENTE', allowedActions: ['CANCEL'])), isTrue);
    });

    test('serveur antérieur : seulement avant paiement', () {
      expect(canClientCancel(_order(status: 'EN_ATTENTE')), isTrue);
      expect(canClientCancel(_order(status: 'PAYER')), isFalse);
    });
  });
}
