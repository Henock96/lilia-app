import 'package:lilia_app/models/order.dart';

/// État d'une étape de la timeline.
enum TimelineStepState { done, current, upcoming }

/// Une étape de la timeline d'une commande.
class TimelineStep {
  const TimelineStep({
    required this.label,
    required this.shortLabel,
    required this.state,
    this.detail,
  });

  /// Libellé complet — annoncé par le lecteur d'écran.
  final String label;

  /// Libellé de la frise horizontale : six étapes côte à côte sur 360 dp.
  final String shortLabel;
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
///
/// L'ordre des deux premières étapes suit le **parcours** de la commande :
/// en « accepter puis payer » (`ACCEPT_FIRST`), la boutique confirme avant le
/// paiement ; en « payer d'abord », le client paie avant qu'elle confirme.
/// Mettre « Confirmée » en tête d'une commande payée d'abord serait faux.
List<TimelineStep> orderTimeline(Order order) {
  final delivery = order.isDelivery;
  final acceptFirst = order.orderFlow == 'ACCEPT_FIRST';
  const payment = ('Paiement', 'Paiement');
  const confirmation = ('Confirmation du vendeur', 'Confirmée');
  final steps = <(String, String)>[
    if (acceptFirst) ...[confirmation, payment] else ...[payment, confirmation],
    ('Préparation', 'Préparation'),
    if (delivery) ...[
      ('Commande prête', 'Prête'),
      ('Livreur en route', 'En route'),
      ('Livrée', 'Livrée'),
    ] else ...[
      ('Prête à récupérer', 'Prête'),
      ('Récupérée', 'Récupérée'),
    ],
  ];

  // Indice de l'étape en cours ; `steps.length` = tout est terminé.
  final (int current, String? detail) = switch (order.status) {
    // Lot 3 — la boutique doit accepter avant que le paiement s'ouvre.
    OrderStatus.demandeEnvoyee => (0, 'En attente de la réponse de la boutique'),
    // Payer d'abord : rien n'est confirmé. Accepter puis payer : la boutique
    // a dit oui, c'est au client.
    OrderStatus.enAttente => (acceptFirst ? 1 : 0, 'En attente de votre paiement'),
    // PAYER / ACCEPTEE : pas de précision ici, `acceptanceLine` (F3-01) la
    // donne juste sous la carte, avec l'heure annoncée par le vendeur. Payée
    // après acceptation, la commande attend sa préparation.
    OrderStatus.payer => (acceptFirst ? 2 : 1, null),
    OrderStatus.acceptee => (2, null),
    OrderStatus.enPreparation => (2, null),
    OrderStatus.pret =>
      delivery
          ? (3, 'En attente du livreur')
          : (3, 'Vous pouvez venir la récupérer'),
    OrderStatus.enRoute => delivery ? (4, null) : (3, null),
    OrderStatus.livrer => (steps.length, null),
    OrderStatus.annuler ||
    OrderStatus.echecLivraison ||
    OrderStatus.unknow => (-1, null),
  };
  if (current < 0) return const [];

  return [
    for (var i = 0; i < steps.length; i++)
      TimelineStep(
        label: steps[i].$1,
        shortLabel: steps[i].$2,
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
