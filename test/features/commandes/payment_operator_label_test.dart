// Libellé de l'opérateur affiché dans le récapitulatif de la fiche commande.
//
// L'opérateur ne se choisit plus à la commande mais au moment de payer :
// `Order.paymentMethod` n'est plus qu'une valeur provisoire exigée par le
// contrat du checkout. Le récapitulatif montre l'opérateur de la **dernière
// tentative** (`GET /payments/by-order/:id`), et le dit quand il n'y en a pas.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/domain/payment_operator_label.dart';

void main() {
  test('opérateurs connus', () {
    expect(paymentOperatorLabel('MTN_MOMO'), 'MTN Mobile Money');
    expect(paymentOperatorLabel('AIRTEL_MONEY'), 'Airtel Money');
  });

  test('aucune tentative : choisi au moment du paiement', () {
    expect(paymentOperatorLabel(null), 'Choisi au moment du paiement');
  });

  test('valeur inconnue rendue telle quelle plutôt que masquée', () {
    expect(paymentOperatorLabel('ORANGE_MONEY'), 'ORANGE_MONEY');
  });

  group('carte récapitulative', () {
    test('la dernière tentative prime sur la valeur provisoire', () {
      expect(
        orderPaymentLabel(
          attemptKnown: true,
          attempt: 'AIRTEL_MONEY',
          paid: true,
          orderMethod: 'MTN_MOMO',
        ),
        'Airtel Money',
      );
    });

    test('tentative pas encore lue : aucun opérateur deviné', () {
      // Payée en Airtel : pendant la relecture (ou si elle échoue), la
      // valeur provisoire `MTN_MOMO` afficherait un faux opérateur.
      expect(
        orderPaymentLabel(
          attemptKnown: false,
          attempt: null,
          paid: true,
          orderMethod: 'MTN_MOMO',
        ),
        '—',
      );
    });

    test('annulée sans paiement : choisi au moment du paiement', () {
      expect(
        orderPaymentLabel(
          attemptKnown: true,
          attempt: null,
          paid: false,
          orderMethod: 'MTN_MOMO',
        ),
        'Choisi au moment du paiement',
      );
    });

    test('commande ancienne payée sans tentative : son opérateur', () {
      expect(
        orderPaymentLabel(
          attemptKnown: true,
          attempt: null,
          paid: true,
          orderMethod: 'AIRTEL_MONEY',
        ),
        'Airtel Money',
      );
    });
  });
}
