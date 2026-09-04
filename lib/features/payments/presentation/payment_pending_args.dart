/// Contexte transmis à l'écran d'attente de paiement.
///
/// Passé par `extra` plutôt que par des paramètres d'URL : le montant et
/// l'opérateur n'ont rien à faire dans une adresse, et surtout, une URL est
/// modifiable. Le montant affiché doit être celui que le serveur a renvoyé à
/// l'initiation, pas une valeur reconstituée depuis la barre d'adresse.
///
/// L'écran fonctionne sans lui (l'identifiant du paiement suffit à interroger le
/// serveur) ; son absence signale une arrivée par lien profond, et la route
/// redirige alors vers la liste des commandes plutôt que d'afficher une attente
/// sans contexte.
class PaymentPendingArgs {
  const PaymentPendingArgs({
    required this.orderId,
    required this.amount,
    required this.method,
  });

  final String orderId;

  /// Montant dû, tel que le serveur l'a calculé — jamais recalculé localement.
  final int amount;

  /// `MTN_MOMO` ou `AIRTEL_MONEY`.
  final String method;
}
