// Parsing des instructions de paiement renvoyées par le backend.
//
// Le client ignorait totalement ce bloc : il affichait un numéro codé en dur
// (dont un placeholder Airtel) et un montant recalculé localement. Ces tests
// verrouillent la lecture des valeurs qui font autorité.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';

void main() {
  group('PaymentResponse — mode MANUAL', () {
    test('expose le numéro, le montant et la référence du serveur', () {
      final res = PaymentResponse.fromJson(<String, dynamic>{
        'paymentId': 'pay-123456789',
        'mode': 'MANUAL',
        'instructions': <String, dynamic>{
          'message': 'Envoyez 11800 FCFA au 06 745 46 10 (MTN MoMo)',
          'reference': '23456789',
          'phone': '06 745 46 10',
          'method': 'MTN_MOMO',
          'methodLabel': 'MTN MoMo',
          'amount': 11800,
          'currency': 'XAF',
          'note': 'Commande 456789 - Chez Maman Lili',
        },
      });

      expect(res.paymentId, 'pay-123456789');
      expect(res.instructions, isNotNull);
      expect(res.instructions!.phone, '06 745 46 10');
      expect(res.instructions!.amount, 11800);
      expect(res.instructions!.reference, '23456789');
      expect(res.instructions!.methodLabel, 'MTN MoMo');
      expect(res.instructions!.note, contains('Chez Maman Lili'));
    });

    test('remonte la référence dans referenceId pour les appelants legacy', () {
      final res = PaymentResponse.fromJson(<String, dynamic>{
        'paymentId': 'pay-1',
        'instructions': <String, dynamic>{'reference': 'ABCD1234'},
      });

      expect(res.referenceId, 'ABCD1234');
    });

    test('un numéro Airtel distinct est bien répercuté', () {
      final res = PaymentResponse.fromJson(<String, dynamic>{
        'paymentId': 'pay-2',
        'instructions': <String, dynamic>{
          'phone': '05 123 45 67',
          'methodLabel': 'Airtel Money',
          'amount': 5000,
          'reference': 'REF12345',
        },
      });

      // Le client affichait un placeholder '05 555 00 01' pour tous les
      // paiements Airtel, quel que soit le numéro réel d'encaissement.
      expect(res.instructions!.phone, '05 123 45 67');
      expect(res.instructions!.methodLabel, 'Airtel Money');
    });

    test('tolère des champs manquants sans lever', () {
      final res = PaymentResponse.fromJson(<String, dynamic>{
        'paymentId': 'pay-3',
        'instructions': <String, dynamic>{},
      });

      expect(res.instructions!.phone, isEmpty);
      expect(res.instructions!.amount, 0);
      expect(res.instructions!.methodLabel, 'Mobile Money');
    });
  });

  group('PaymentResponse — mode MTN automatique', () {
    test('pas de bloc instructions, referenceId lu à la racine', () {
      final res = PaymentResponse.fromJson(<String, dynamic>{
        'paymentId': 'pay-4',
        'referenceId': 'mtn-ref-uuid',
      });

      expect(res.instructions, isNull);
      expect(res.referenceId, 'mtn-ref-uuid');
      expect(res.message, 'Paiement initié');
    });
  });

  group('PaymentStatusResponse', () {
    test('mappe les statuts du backend', () {
      for (final entry in {
        'PENDING': PaymentStatus.pending,
        'SUCCESS': PaymentStatus.success,
        'SUCCESSFUL': PaymentStatus.success,
        'FAILED': PaymentStatus.failed,
        'CANCELLED': PaymentStatus.cancelled,
      }.entries) {
        final res = PaymentStatusResponse.fromJson(<String, dynamic>{
          'paymentId': 'p',
          'status': entry.key,
        });
        expect(res.status, entry.value, reason: entry.key);
      }
    });

    test('un statut inconnu reste PENDING plutôt que de lever', () {
      final res = PaymentStatusResponse.fromJson(<String, dynamic>{
        'paymentId': 'p',
        'status': 'QUELQUE_CHOSE',
      });

      expect(res.status, PaymentStatus.pending);
    });
  });
}
