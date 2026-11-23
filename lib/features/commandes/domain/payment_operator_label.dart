/// Libellé de l'opérateur Mobile Money d'une commande, pour le récapitulatif.
///
/// [method] est l'opérateur de la **dernière tentative de paiement** : depuis
/// que l'opérateur se choisit au moment de payer, `Order.paymentMethod` n'est
/// plus qu'une valeur provisoire exigée par le contrat du checkout. `null` :
/// aucune tentative encore.
///
/// Une valeur inconnue est rendue telle quelle : un opérateur ajouté côté
/// serveur reste lisible au lieu de disparaître.
String paymentOperatorLabel(String? method) => switch (method) {
  null => 'Choisi au moment du paiement',
  'MTN_MOMO' => 'MTN Mobile Money',
  'AIRTEL_MONEY' => 'Airtel Money',
  _ => method,
};

/// Libellé de la carte récapitulative d'une commande.
///
/// - [attempt] : opérateur de la dernière tentative, quand la lecture a abouti ;
/// - [attemptKnown] : `false` tant que la tentative n'est pas lue (chargement,
///   échec réseau) — on ne devine pas : `Order.paymentMethod` vaut `MTN_MOMO`
///   pour toute commande récente, un paiement Airtel s'afficherait « MTN » ;
/// - [paid] : la commande a été encaissée ; seule une commande payée **sans**
///   tentative connue (commande ancienne) retombe sur [orderMethod].
String orderPaymentLabel({
  required bool attemptKnown,
  required String? attempt,
  required bool paid,
  required String? orderMethod,
}) {
  if (attempt != null) return paymentOperatorLabel(attempt);
  if (!attemptKnown) return '—';
  return paymentOperatorLabel(paid ? orderMethod : null);
}
