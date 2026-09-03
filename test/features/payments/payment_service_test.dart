import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';

/// Contrat du service de paiement côté client.
///
/// Deux propriétés y sont verrouillées :
///  1. **le format du numéro** — s'en écarter fait partir une demande de
///     paiement vers un numéro qui n'existe pas, sans erreur visible ;
///  2. **le mode décide de l'écran suivant** — basculer de rail côté serveur ne
///     doit pas exiger une release sur les stores.
void main() {
  // Aucun appel réseau dans ces tests : seuls le formatage du numéro et le
  // parsing des réponses sont exercés. L'ApiClient est construit mais jamais
  // sollicité.
  final service = PaymentService(
    api: ApiClient.test(
      baseUrl: 'http://localhost',
      tokenProvider: () async => null,
      forceRefreshToken: () async => null,
    ),
  );

  group('formatPhoneNumber — Congo-Brazzaville', () {
    test('conserve le zéro initial, qui fait partie du numéro', () {
      // ⚠️ Régression corrigée avec pawaPay : cette méthode SUPPRIMAIT ce zéro
      // (`24261234567`), alors que le backend le conserve
      // (`formatMtnPhoneNumber` préfixe `242` sans rien retirer). Tant que
      // l'encaissement était manuel, un humain lisait le numéro et la
      // divergence passait inaperçue.
      expect(service.formatPhoneNumber('061234567'), '242061234567');
      expect(service.formatPhoneNumber('051234567'), '242051234567');
      expect(service.formatPhoneNumber('041234567'), '242041234567');
    });

    test('normalise les écritures usuelles vers la même valeur', () {
      const expected = '242061234567';
      for (final input in [
        '061234567',
        '06 12 34 567',
        '06-12-34-567',
        '+242061234567',
        '00242061234567',
        '242061234567',
        ' 06 1234 567 ',
      ]) {
        expect(
          service.formatPhoneNumber(input),
          expected,
          reason: 'entrée « $input »',
        );
      }
    });
  });

  group('validatePhoneNumber', () {
    test('accepte les mobiles congolais', () {
      expect(service.validatePhoneNumber('061234567'), isTrue);
      expect(service.validatePhoneNumber('+242 05 123 45 67'), isTrue);
      expect(service.validatePhoneNumber('042345678'), isTrue);
    });

    test('rejette ce qui n’est pas un mobile congolais', () {
      expect(service.validatePhoneNumber('011234567'), isFalse); // préfixe
      expect(service.validatePhoneNumber('06123456'), isFalse); // trop court
      expect(service.validatePhoneNumber('0612345678'), isFalse); // trop long
      expect(service.validatePhoneNumber(''), isFalse);
      expect(service.validatePhoneNumber('+33612345678'), isFalse); // hors Congo
    });
  });

  group('PaymentResponse', () {
    test('mode PAWAPAY → parcours interactif', () {
      final res = PaymentResponse.fromJson({
        'paymentId': 'pay-1',
        'orderId': 'o1',
        'status': 'PENDING',
        'provider': 'PAWAPAY',
        'method': 'MTN_MOMO',
        'amount': 6400,
        'currency': 'XAF',
        'pollAfterMs': 3000,
        'mode': 'PAWAPAY',
      });

      expect(res.isInteractive, isTrue);
      expect(res.isSettled, isFalse);
      expect(res.amount, 6400);
      expect(res.pollAfterMs, 3000);
      expect(res.instructions, isNull);
    });

    test('mode MANUAL → instructions de virement, pas d’écran d’attente', () {
      final res = PaymentResponse.fromJson({
        'paymentId': 'pay-2',
        'mode': 'MANUAL',
        'instructions': {
          'message': 'Envoyez 6400 FCFA au 060000000 (MTN MoMo)',
          'reference': 'ABCD1234',
          'phone': '060000000',
          'methodLabel': 'MTN MoMo',
          'amount': 6400,
          'currency': 'XAF',
        },
      });

      expect(res.isInteractive, isFalse);
      expect(res.instructions, isNotNull);
      expect(res.instructions!.phone, '060000000');
      // Le montant vient des instructions serveur quand il n'est pas à la racine.
      expect(res.amount, 6400);
    });

    test('commande réglée en points → rien à payer', () {
      final res = PaymentResponse.fromJson({
        'paymentId': 'pay-3',
        'mode': 'ZERO_AMOUNT',
        'status': 'SUCCESS',
        'amount': 0,
      });

      expect(res.isSettled, isTrue);
      expect(res.isInteractive, isFalse);
    });

    test('un mode inconnu retombe sur le parcours manuel, jamais sur une erreur', () {
      // Le backend peut ajouter un rail avant que l'application soit mise à
      // jour : dégrader vaut mieux que planter au moment de payer.
      final res = PaymentResponse.fromJson({
        'paymentId': 'pay-4',
        'mode': 'UN_RAIL_FUTUR',
      });
      expect(res.isInteractive, isFalse);
      expect(res.paymentId, 'pay-4');
    });
  });

  group('PaymentStatusResponse', () {
    test('distingue les états terminaux de l’attente', () {
      for (final raw in ['SUCCESS', 'FAILED', 'CANCELLED']) {
        final s = PaymentStatusResponse.fromJson({
          'paymentId': 'p',
          'status': raw,
        });
        expect(s.isTerminal, isTrue, reason: raw);
      }
      final pending = PaymentStatusResponse.fromJson({
        'paymentId': 'p',
        'status': 'PENDING',
      });
      expect(pending.isTerminal, isFalse);
    });

    test('conserve code et message techniques pour les journaux', () {
      final s = PaymentStatusResponse.fromJson({
        'paymentId': 'p',
        'status': 'FAILED',
        'failureCode': 'PAYER_LIMIT_REACHED',
        'failureMessage': 'Solde insuffisant sur votre compte.',
      });

      // Les deux champs restent lisibles — ils appartiennent aux journaux.
      expect(s.failureCode, 'PAYER_LIMIT_REACHED');
      expect(s.failureMessage, 'Solde insuffisant sur votre compte.');
    });
  });
}
