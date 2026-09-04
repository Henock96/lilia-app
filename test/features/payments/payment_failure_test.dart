import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/payments/domain/payment_failure.dart';

/// Traduction des échecs de paiement.
///
/// Ces tests protègent une promesse simple : **aucun texte venu d'un opérateur
/// n'atteint l'écran d'un client**. Elle a été rompue en production — un client
/// a lu, dans une notification, « "Airtel_CG" did not specify a reason for this
/// faliure », faute d'orthographe comprise.
///
/// Deux propriétés sont vérifiées ici :
///  · la traduction part du **code**, jamais du message libre ;
///  · on n'invente **jamais** une cause quand l'opérateur n'en donne pas.
void main() {
  group('mapPaymentFailure', () {
    test('un code inconnu donne un message générique, sans cause inventée', () {
      // `UNSPECIFIED_FAILURE` est documenté par pawaPay comme « l'opérateur a
      // confirmé l'échec sans en donner la raison ». Afficher « solde
      // insuffisant » ici enverrait le client vérifier un solde hors de cause.
      final message = mapPaymentFailure(
        status: PaymentStatus.failed,
        failureCode: 'UNSPECIFIED_FAILURE',
      );

      expect(message.title, 'Paiement non abouti');
      expect(message.body, contains('n’a pas pu être finalisé'));
      expect(message.body.toLowerCase(), isNot(contains('solde')));
      expect(message.canRetry, isTrue);
    });

    test('un code absent donne le même message générique', () {
      final message = mapPaymentFailure(status: PaymentStatus.failed);
      expect(message.title, 'Paiement non abouti');
      expect(message.canRetry, isTrue);
    });

    test('une cause précise est dite précisément', () {
      expect(
        mapPaymentFailure(
          status: PaymentStatus.failed,
          failureCode: 'INSUFFICIENT_BALANCE',
        ).title,
        'Solde insuffisant',
      );
      expect(
        mapPaymentFailure(
          status: PaymentStatus.failed,
          failureCode: 'PAYER_NOT_FOUND',
        ).title,
        'Numéro incorrect',
      );
    });

    test('un refus du client n’est pas présenté comme une panne', () {
      final message = mapPaymentFailure(
        status: PaymentStatus.failed,
        failureCode: 'PAYMENT_NOT_APPROVED',
      );
      expect(message.title, 'Paiement annulé');
      expect(message.body.toLowerCase(), isNot(contains('erreur')));
    });

    test('un délai dépassé est dit « expiré », pas « échoué »', () {
      final message = mapPaymentFailure(
        status: PaymentStatus.failed,
        failureCode: 'RECONCILIATION_TIMEOUT',
      );
      expect(message.title, 'Le paiement a expiré');
      expect(message.canRetry, isTrue);
    });

    test('PENDING n’est jamais présenté comme un échec, et interdit la reprise', () {
      final message = mapPaymentFailure(status: PaymentStatus.pending);
      expect(message.title, 'Paiement en cours');
      expect(message.body.toLowerCase(), isNot(contains('échou')));
      // La garantie anti-double-débit côté écran : tant que l'issue n'est pas
      // tranchée, « Réessayer » ne doit pas exister.
      expect(message.canRetry, isFalse);
    });

    test('le succès ne propose pas de reprise', () {
      final message = mapPaymentFailure(status: PaymentStatus.success);
      expect(message.title, 'Paiement confirmé');
      expect(message.canRetry, isFalse);
    });

    test('la casse et les espaces du code n’ont pas d’importance', () {
      expect(
        mapPaymentFailure(
          status: PaymentStatus.failed,
          failureCode: '  insufficient_balance ',
        ).title,
        'Solde insuffisant',
      );
    });

    /// Le test central : quoi qu'on lui donne, le mapper ne recrache jamais
    /// l'entrée. Un code inconnu ne doit pas se retrouver à l'écran, même
    /// partiellement.
    test('⚠️ aucun code technique ne fuit dans le texte affiché', () {
      const codes = [
        'UNSPECIFIED_FAILURE',
        'UNKNOWN_ERROR',
        'PROVIDER_REJECTED',
        'PAWAPAY_WALLET_OUT_OF_FUNDS',
        'AIRTEL_COG_WEIRD_CODE',
        'INSUFFICIENT_BALANCE',
        'RECONCILIATION_TIMEOUT',
      ];

      for (final code in codes) {
        final message = mapPaymentFailure(
          status: PaymentStatus.failed,
          failureCode: code,
        );
        final rendered = '${message.title} ${message.body}';
        expect(rendered, isNot(contains(code)), reason: 'code $code affiché');
        expect(rendered, isNot(contains('_')), reason: 'jargon dans « $code »');
        expect(rendered, isNot(contains('pawaPay')));
        expect(rendered, isNot(contains('Airtel_')));
        expect(message.title, isNotEmpty);
        expect(message.body, isNotEmpty);
      }
    });
  });

  group('outcomeOf', () {
    test('distingue expiré, annulé et échoué à partir du code', () {
      expect(
        outcomeOf(
          status: PaymentStatus.failed,
          failureCode: 'RECONCILIATION_TIMEOUT',
        ),
        PaymentOutcome.expired,
      );
      expect(
        outcomeOf(
          status: PaymentStatus.failed,
          failureCode: 'PAYMENT_NOT_APPROVED',
        ),
        PaymentOutcome.cancelled,
      );
      expect(
        outcomeOf(status: PaymentStatus.failed, failureCode: 'UNKNOWN_ERROR'),
        PaymentOutcome.failed,
      );
    });

    test('PENDING reste PENDING — ni succès, ni échec', () {
      expect(
        outcomeOf(status: PaymentStatus.pending),
        PaymentOutcome.pending,
      );
    });

    test('le statut serveur prime : CANCELLED reste une annulation', () {
      expect(
        outcomeOf(status: PaymentStatus.cancelled, failureCode: 'ADMIN_REJECTED'),
        PaymentOutcome.cancelled,
      );
    });
  });
}
