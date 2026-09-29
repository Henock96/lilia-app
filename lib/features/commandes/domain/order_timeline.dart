import 'package:lilia_app/models/order.dart';

/// État d'une étape de la timeline.
enum TimelineStepState { done, current, upcoming }

/// Une étape de la timeline d'une commande.
class TimelineStep {
  const TimelineStep({required this.label, required this.state, this.detail});

  final String label;
  final TimelineStepState state;

  /// Précision sur l'étape **en cours** (« en attente de la réponse du
  /// vendeur »), `null` sinon.
  final String? detail;
}

/// Timeline d'une commande, **selon son mode** (P3-09).
///
/// L'ancien stepper à 4 étapes (« Confirmée / En préparation / Prête / En
/// route ») était faux sur quatre points : `EN_ATTENTE` s'affichait
/// « Confirmée — en cours » alors que la commande attendait son paiement ;
/// `PAYER` et `ACCEPTEE` n'avaient aucune étape en cours ; un **retrait**
/// affichait « En route », qui n'arrive jamais ; aucune étape « Livrée ».
///
/// Les étapes sont des **phases** : l'étape « en cours » est celle que la
/// commande est en train de vivre. Rien n'est inventé — seul le statut serveur
/// est lu ; aucune heure n'est affichée ici (la ligne « prête vers HH:MM »
/// d'`acceptanceLine` reste la seule heure, et elle vient du serveur).
///
/// Renvoie une liste **vide** pour les statuts terminaux hors parcours
/// (annulée, échec de livraison) et les statuts inconnus : l'écran affiche
/// alors leur carte dédiée plutôt qu'une progression fausse.
List<TimelineStep> orderTimeline(Order order) {
  final delivery = order.isDelivery;
  final labels = delivery
      ? const [
          'Paiement',
          'Confirmation du vendeur',
          'Préparation',
          'Commande prête',
          'Livreur en route',
          'Livrée',
        ]
      : const [
          'Paiement',
          'Confirmation du vendeur',
          'Préparation',
          'Prête à récupérer',
          'Récupérée',
        ];

  // Indice de l'étape en cours ; `labels.length` = tout est terminé.
  final (int current, String? detail) = switch (order.status) {
    OrderStatus.enAttente => (0, 'En attente de votre paiement'),
    // PAYER / ACCEPTEE : pas de précision ici, `acceptanceLine` (F3-01) la
    // donne juste sous la carte, avec l'heure annoncée par le vendeur.
    OrderStatus.payer => (1, null),
    OrderStatus.acceptee => (2, null),
    OrderStatus.enPreparation => (2, null),
    OrderStatus.pret =>
      delivery
          ? (3, 'En attente du livreur')
          : (3, 'Vous pouvez venir la récupérer'),
    OrderStatus.enRoute => delivery ? (4, null) : (3, null),
    OrderStatus.livrer => (labels.length, null),
    OrderStatus.annuler ||
    OrderStatus.echecLivraison ||
    OrderStatus.unknow => (-1, null),
  };
  if (current < 0) return const [];

  return [
    for (var i = 0; i < labels.length; i++)
      TimelineStep(
        label: labels[i],
        state: i < current
            ? TimelineStepState.done
            : i == current
            ? TimelineStepState.current
            : TimelineStepState.upcoming,
        detail: i == current ? detail : null,
      ),
  ];
}

/// Au-delà, une position n'est plus assez récente pour annoncer une durée.
const kEtaFreshness = Duration(minutes: 5);

/// Borne haute de cohérence : au-delà, l'estimation est jugée aberrante.
const kEtaMaxMinutes = 180;

/// Ligne d'ETA du livreur (P3.1.7), ou `null` si le livreur ne roule pas
/// encore vers le client.
///
/// L'ETA vient du serveur (`tracking.service.ts#calculateETA`) : distance à
/// vol d'oiseau à 25 km/h, recalculée à chaque position. Deux conséquences :
///
/// - `0` est renvoyé quand la destination est **inconnue** — ce n'est pas
///   « arrivé » : on le traite comme indisponible ;
/// - c'est une estimation, et elle est présentée comme telle (« environ »).
///
/// Position trop ancienne ([kEtaFreshness]) ou valeur incohérente : pas de
/// chiffre, une phrase de remplacement.
String? etaLine({
  required bool onTheWay,
  required int? etaMinutes,
  required DateTime? positionAt,
  required DateTime now,
}) {
  if (!onTheWay) return null;
  const indisponible = 'Heure d\'arrivée pas encore estimée';
  final eta = etaMinutes;
  if (eta == null || eta <= 0 || eta > kEtaMaxMinutes) return indisponible;
  if (positionAt == null || now.difference(positionAt) > kEtaFreshness) {
    return 'Estimation en attente d\'une position récente du livreur';
  }
  // Durée restante à partir de maintenant, pas de l'émission de la position.
  final ecoule = now.difference(positionAt).inMinutes;
  final reste = eta - (ecoule < 0 ? 0 : ecoule);
  if (reste <= 1) return 'Arrivée estimée : d\'un instant à l\'autre';
  return 'Arrivée estimée : environ $reste min';
}
