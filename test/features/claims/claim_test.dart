import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/claims/domain/claim.dart';

void main() {
  group('ClaimDraft (F3-06)', () {
    test('les articles sont exigés pour manquant / erroné / abîmé', () {
      expect(
        const ClaimDraft(reason: ClaimReason.missingItem).isComplete,
        isFalse,
      );
      expect(
        const ClaimDraft(
          reason: ClaimReason.missingItem,
          items: {'i1': 1},
        ).isComplete,
        isTrue,
      );
      expect(const ClaimDraft(reason: ClaimReason.late).isComplete, isTrue);
    });

    test('n’envoie ni article décoché, ni note vide, ni montant', () {
      const draft = ClaimDraft(
        reason: ClaimReason.damaged,
        items: {'i1': 2, 'i2': 0},
        note: '   ',
      );
      expect(draft.toJson(), {
        'reason': 'DAMAGED',
        'items': [
          {'orderItemId': 'i1', 'quantity': 2},
        ],
      });
    });
  });

  test('ClaimDetail lit le fil, les remboursements et l’avoir', () {
    final claim = ClaimDetail.fromJson({
      'id': 'c1',
      'orderRef': 'ABCD1234',
      'status': 'RESOLVED',
      'reason': 'MISSING_ITEM',
      'outcome': 'VOUCHER',
      'order': {
        'restaurant': {'nom': 'Chez Lili'},
      },
      'items': [
        {'orderItemId': 'i1', 'quantity': 1, 'label': 'Alloco'},
      ],
      'messages': [
        {
          'id': 'm1',
          'authorLabel': 'Service client Lilia',
          'mine': false,
          'body': 'Bonjour',
          'createdAt': '2026-09-25T10:00:00.000Z',
        },
      ],
      'refunds': <Object>[],
      'voucher': {
        'code': 'AVOIR-ABCD2345',
        'amountXaf': 1000,
        'expiresAt': '2026-10-25T10:00:00.000Z',
      },
    });
    expect(claim.restaurantName, 'Chez Lili');
    expect(claim.items.single.label, 'Alloco');
    expect(claim.messages.single.authorLabel, 'Service client Lilia');
    expect(claim.voucher?.code, 'AVOIR-ABCD2345');
    expect(claimStatusLabel(claim.status, claim.outcome), 'Avoir offert');
  });

  test('les signalements antérieurs gardent un libellé', () {
    expect(claimReasonLabel('NOT_RECEIVED'), 'Commande non reçue');
  });
}
