import 'package:lilia_app/models/location_precision.dart';
import 'package:lilia_app/models/quartier.dart';

/// Une adresse de livraison enregistrée par le client.
///
/// Elle porte sa **propre** position depuis septembre 2026. Avant, la seule
/// coordonnée disponible à la commande était le GPS du téléphone : commander
/// depuis son bureau pour une livraison à domicile envoyait le livreur au
/// bureau. « Où je suis » et « où on me livre » sont deux informations
/// distinctes.
class Adresse {
  final String id;
  final String rue;
  final String ville;
  final String? etat;
  final String country;
  final String userId;
  final String? quartierId;
  final Quartier? quartier;

  /// Position de l'adresse. `null` tant que le client ne l'a pas posée sur la
  /// carte — les adresses créées avant cette évolution n'en ont pas.
  final double? latitude;
  final double? longitude;

  /// Fiabilité de la position ci-dessus, telle que le serveur la qualifie.
  final LocationPrecision locationPrecision;

  /// Repères pour le livreur : « portail bleu face à la pharmacie ».
  final String? landmark;

  /// Nom donné par le client : « Maison », « Bureau ».
  final String? label;

  /// Adresse par défaut du client, telle que **le serveur** la désigne.
  ///
  /// Le champ existait en base et l'endpoint `PATCH /adresses/:id/default`
  /// aussi, mais le client ne lisait ni l'un ni l'autre : il posait le badge
  /// « Principale » sur le premier élément d'une liste triée par date de
  /// création décroissante. Le badge désignait donc la **dernière adresse
  /// créée**, et changeait tout seul dès qu'on en ajoutait une — y compris une
  /// adresse ponctuelle saisie pour une seule commande.
  final bool isDefault;

  Adresse({
    required this.id,
    required this.rue,
    required this.ville,
    this.etat,
    required this.country,
    required this.userId,
    this.quartierId,
    this.quartier,
    this.latitude,
    this.longitude,
    this.locationPrecision = LocationPrecision.unknown,
    this.landmark,
    this.label,
    this.isDefault = false,
  });

  factory Adresse.fromJson(Map<String, dynamic> json) {
    return Adresse(
      id: json['id'] as String,
      rue: json['rue'] as String,
      ville: json['ville'] as String,
      etat: json['etat'] as String?,
      country: json['country'] as String,
      userId: json['userId'] as String,
      quartierId: json['quartierId'] as String?,
      quartier: json['quartier'] != null
          ? Quartier.fromJson(json['quartier'] as Map<String, dynamic>)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationPrecision: LocationPrecision.fromWire(
        json['locationPrecision'] as String?,
      ),
      landmark: json['landmark'] as String?,
      label: json['label'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// Libellé à afficher : le nom donné par le client s'il en a mis un, la rue
  /// sinon. « Maison » situe mieux qu'« Avenue de la Paix » dans une liste où
  /// trois adresses se ressemblent.
  String get displayLabel =>
      (label != null && label!.trim().isNotEmpty) ? label!.trim() : rue;

  /// `true` si l'adresse porte une position posée par le client.
  bool get hasPosition => latitude != null && longitude != null;

  /// Ce que le livreur pourra réellement viser.
  ///
  /// Une adresse sans position reste livrable — le serveur retombe sur le
  /// centroïde du quartier — mais l'écran d'adresses le signale, pour que le
  /// client puisse compléter avant de commander plutôt qu'après.
  bool get needsPosition => !hasPosition;

  // Pour l'affichage
  @override
  String toString() {
    if (quartier != null) {
      return '$rue, ${quartier!.nom}';
    }
    return rue;
  }

  // Vérifie si l'adresse a un quartier associé
  bool get hasQuartier => quartierId != null && quartierId!.isNotEmpty;
}
