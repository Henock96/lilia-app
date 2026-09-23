import 'package:lilia_app/models/order.dart';

/// Ce que le client voit de l'acceptation vendeur (Phase 3, F3-01).
///
/// Fonctions pures, testées (`order_acceptance_view_test.dart`), alignées
/// sur le site (`apps/web/lib/order-status-view.ts`) : les deux clients
/// doivent dire la même chose de la même commande.

/// Brazzaville est à UTC+1 toute l'année (pas d'heure d'été) — même règle
/// que le cron d'ouverture côté serveur.
String _hhmmBrazzaville(DateTime at) {
  final local = at.toUtc().add(const Duration(hours: 1));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

/// Ligne d'état sous la progression, ou `null` s'il n'y a rien à dire.
String? acceptanceLine(Order order) {
  final readyAt = order.estimatedReadyAt;
  switch (order.status) {
    case OrderStatus.payer:
      return 'En attente de la réponse du vendeur';
    case OrderStatus.acceptee:
      return readyAt == null
          ? 'Acceptée par le vendeur'
          : 'Acceptée par le vendeur · prête vers ${_hhmmBrazzaville(readyAt)}';
    case OrderStatus.enPreparation:
      return readyAt == null ? null : 'Prête vers ${_hhmmBrazzaville(readyAt)}';
    default:
      return null;
  }
}

const _rejectionText = {
  'OUT_OF_STOCK': 'rupture de stock',
  'TOO_BUSY': 'trop de commandes en cours',
  'CLOSING': 'fermeture imminente',
  'OUT_OF_ZONE': 'adresse hors de sa zone de livraison',
  'OTHER': 'indisponibilité',
};

/// Message d'une commande annulée. Payée ⇒ refusée ou laissée sans réponse
/// par le vendeur : le remboursement part automatiquement, il faut le dire.
({String title, String detail}) cancellationNotice(Order order) {
  if (order.paidAt == null) {
    return (
      title: 'Commande annulée',
      detail: 'Cette commande a été annulée. Aucun montant n’a été débité.',
    );
  }
  final vendor = order.restaurant.nom.isEmpty ? 'Le vendeur' : order.restaurant.nom;
  final motive = _rejectionText[order.vendorRejectionReason];
  return (
    title: '$vendor n’a pas pu prendre votre commande',
    detail: 'Votre commande a été annulée${motive == null ? '' : ' ($motive)'}. '
        'Votre remboursement est en cours sur le numéro qui a payé.',
  );
}

/// Le serveur fait foi quand il publie ses gestes ; face à un serveur
/// antérieur, seulement avant paiement (règle H5).
bool canClientCancel(Order order) {
  final published = order.allowedActions;
  if (published != null) return published.contains('CANCEL');
  return order.status == OrderStatus.enAttente;
}
