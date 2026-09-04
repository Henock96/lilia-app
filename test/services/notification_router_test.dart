import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/services/notification_router.dart';

/// Ce test fige la correspondance entre ce que le backend **émet réellement**
/// et ce que l'app en fait. Les types viennent de `OrdersListener`,
/// `PaymentListener` et `DeliveriesListener` (backend).
void main() {
  const router = NotificationRouter();

  group('rafraîchissement', () {
    test('tout payload portant un orderId recharge les commandes', () {
      final action = router.resolve(
        {'type': 'status_update', 'orderId': 'o1', 'status': 'EN_PREPARATION'},
        trigger: NotificationTrigger.foreground,
      );

      expect(action.refresh, NotificationTarget.orders);
      expect(action.orderId, 'o1');
    });

    test('sans orderId, aucune action', () {
      final action = router.resolve(
        {'type': 'new_menu'},
        trigger: NotificationTrigger.foreground,
      );

      expect(action, NotificationAction.none);
    });

    test('un type inconnu portant un orderId rafraîchit quand même', () {
      // Si le backend introduit un type, l'app ne doit pas cesser de se
      // rafraîchir en attendant sa mise à jour.
      final action = router.resolve(
        {'type': 'un_type_qui_nexiste_pas_encore', 'orderId': 'o1'},
        trigger: NotificationTrigger.foreground,
      );

      expect(action.refresh, NotificationTarget.orders);
      expect(action.intent, NotificationIntent.none);
    });
  });

  group('navigation', () {
    test('un tap ouvre le détail de la commande', () {
      final action = router.resolve(
        {'type': 'status_update', 'orderId': 'o1'},
        trigger: NotificationTrigger.tap,
      );

      expect(action.route, '/commandes/o1');
    });

    test('en foreground, on rafraîchit sans déplacer le client', () {
      // Recevoir « commande en préparation » pendant qu'on choisit un plat ne
      // doit pas fermer l'écran en cours.
      final action = router.resolve(
        {'type': 'status_update', 'orderId': 'o1'},
        trigger: NotificationTrigger.foreground,
      );

      expect(action.route, isNull);
      expect(action.refresh, NotificationTarget.orders);
    });
  });

  group('intentions', () {
    test('commande livrée → invite à noter le livreur', () {
      final action = router.resolve(
        {'type': 'status_update', 'orderId': 'o1', 'status': 'LIVRER'},
        trigger: NotificationTrigger.tap,
      );

      expect(action.intent, NotificationIntent.rateDelivery);
    });

    test('un autre statut ne propose rien', () {
      for (final status in ['PAYER', 'EN_PREPARATION', 'PRET', 'EN_ROUTE']) {
        final action = router.resolve(
          {'type': 'status_update', 'orderId': 'o1', 'status': status},
          trigger: NotificationTrigger.tap,
        );
        expect(action.intent, NotificationIntent.none, reason: status);
      }
    });

    test('paiement échoué ou expiré → proposer de réessayer', () {
      for (final type in ['payment_failed', 'payment_timeout']) {
        final action = router.resolve(
          {'type': type, 'orderId': 'o1'},
          trigger: NotificationTrigger.tap,
        );
        expect(action.intent, NotificationIntent.retryPayment, reason: type);
      }
    });

    test('incident de livraison → information, sans promesse d’issue', () {
      final action = router.resolve(
        {'type': 'delivery_failed_customer', 'orderId': 'o1'},
        trigger: NotificationTrigger.tap,
      );

      expect(action.intent, NotificationIntent.deliveryIncident);
    });

    test('paiement confirmé : rien de particulier à proposer', () {
      final action = router.resolve(
        {'type': 'payment_confirmed', 'orderId': 'o1'},
        trigger: NotificationTrigger.tap,
      );

      expect(action.intent, NotificationIntent.none);
      expect(action.refresh, NotificationTarget.orders);
    });
  });
}
