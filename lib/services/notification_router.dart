/// D'où vient le message FCM en cours de traitement.
///
/// La distinction est ce qui évite qu'une notification reçue **pendant** que le
/// client remplit son panier ne le projette sur une autre page. Seul un tap
/// explicite autorise une navigation.
enum NotificationTrigger { foreground, tap }

/// Ce qu'il faut rafraîchir à réception.
enum NotificationTarget { orders }

/// Suggestion d'action à proposer au client, une fois sur l'écran.
///
/// Ces intentions n'existaient pas : le service se contentait de poser
/// `latestUpdatedOrderIdProvider` et de recharger la liste, quel que soit
/// l'événement. Une livraison terminée, un paiement échoué et une commande
/// annulée déclenchaient donc exactement la même chose — impossible d'ouvrir
/// la notation après une livraison ou de proposer de reprendre un paiement.
enum NotificationIntent {
  /// Rien de particulier à proposer.
  none,

  /// Commande livrée : on peut inviter le client à noter le livreur.
  rateDelivery,

  /// Paiement échoué ou expiré : proposer de réessayer.
  retryPayment,

  /// Incident de livraison : afficher l'information sans promettre d'issue.
  deliveryIncident,
}

/// Ce que l'app doit faire en réponse à un message FCM.
class NotificationAction {
  const NotificationAction({
    this.refresh,
    this.orderId,
    this.route,
    this.intent = NotificationIntent.none,
  });

  /// Provider à recharger, `null` si rien à faire.
  final NotificationTarget? refresh;

  /// Commande concernée, si le payload en porte une.
  final String? orderId;

  /// Route go_router à ouvrir — `null` hors d'un tap explicite.
  final String? route;

  /// Action à proposer au client une fois l'écran affiché.
  final NotificationIntent intent;

  static const none = NotificationAction();

  @override
  bool operator ==(Object other) =>
      other is NotificationAction &&
      other.refresh == refresh &&
      other.orderId == orderId &&
      other.route == route &&
      other.intent == intent;

  @override
  int get hashCode => Object.hash(refresh, orderId, route, intent);

  @override
  String toString() =>
      'NotificationAction(refresh: $refresh, orderId: $orderId, '
      'route: $route, intent: $intent)';
}

/// Traduit le payload `data` d'un push FCM en action applicative.
///
/// Volontairement pur : aucune dépendance à Firebase, Riverpod ou go_router,
/// pour que la correspondance avec ce qu'émet réellement le backend
/// (`OrdersListener`, `PaymentListener`, `DeliveriesListener`) soit
/// vérifiable directement, sans lancer l'application.
///
/// Même rôle que `notification_router.dart` dans les apps livreur et admin —
/// le client était la seule des trois à ne pas en avoir.
class NotificationRouter {
  const NotificationRouter();

  NotificationAction resolve(
    Map<String, dynamic> data, {
    required NotificationTrigger trigger,
  }) {
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;
    final hasOrder = orderId != null && orderId.isNotEmpty;

    // Sans commande rattachée, il n'y a rien à recharger côté client (les
    // notifications vendeur/livreur n'atterrissent pas ici).
    if (!hasOrder) return NotificationAction.none;

    final intent = _intentFor(type, data);

    return NotificationAction(
      refresh: NotificationTarget.orders,
      orderId: orderId,
      // On ne navigue qu'au tap : rafraîchir en arrière-plan est utile,
      // déplacer quelqu'un qui est en train de commander ne l'est pas.
      route: trigger == NotificationTrigger.tap ? '/commandes/$orderId' : null,
      intent: intent,
    );
  }

  NotificationIntent _intentFor(String? type, Map<String, dynamic> data) {
    switch (type) {
      case 'payment_failed':
      case 'payment_timeout':
        return NotificationIntent.retryPayment;

      case 'delivery_failed_customer':
        return NotificationIntent.deliveryIncident;

      case 'status_update':
        // Le backend transporte le statut d'arrivée dans le payload : c'est
        // lui qui distingue « en préparation » de « livrée », pas le type.
        return data['status'] == 'LIVRER'
            ? NotificationIntent.rateDelivery
            : NotificationIntent.none;

      default:
        return NotificationIntent.none;
    }
  }
}
