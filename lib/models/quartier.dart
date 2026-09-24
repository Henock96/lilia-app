class Quartier {
  final String id;
  final String nom;
  final String ville;

  Quartier({required this.id, required this.nom, required this.ville});

  factory Quartier.fromJson(Map<String, dynamic> json) {
    return Quartier(
      id: json['id'] as String,
      nom: json['nom'] as String,
      ville: json['ville'] as String? ?? 'Brazzaville',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nom': nom, 'ville': ville};
  }

  @override
  String toString() => nom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quartier && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class DeliveryFeeResult {
  final String mode;

  /// Prix payé par le client, dans les trois modes : la seule valeur à lire
  /// pour un montant.
  final double fee;
  final String? zoneName;
  final String? quartierName;
  final bool isDefaultZone;

  /// Mode `PLATFORM` (F3-02) — prix de base de la grille, avant la part
  /// offerte par le vendeur. `null` dans les autres modes.
  final double? baseFee;

  /// Part de la livraison offerte par le vendeur, retenue sur son reversement.
  final double vendorSubsidy;

  /// « Livraison offerte dès X » du vendeur, `null` s'il n'en propose pas.
  final double? freeDeliveryThreshold;

  DeliveryFeeResult({
    required this.mode,
    required this.fee,
    this.zoneName,
    this.quartierName,
    this.isDefaultZone = false,
    this.baseFee,
    this.vendorSubsidy = 0,
    this.freeDeliveryThreshold,
  });

  factory DeliveryFeeResult.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeResult(
      mode: json['mode'] as String,
      fee: (json['fee'] as num).toDouble(),
      zoneName: json['zoneName'] as String?,
      quartierName: json['quartierName'] as String?,
      isDefaultZone: json['isDefaultZone'] as bool? ?? false,
      baseFee: (json['baseFee'] as num?)?.toDouble(),
      vendorSubsidy: (json['vendorSubsidy'] as num?)?.toDouble() ?? 0,
      freeDeliveryThreshold: (json['freeDeliveryThreshold'] as num?)
          ?.toDouble(),
    );
  }

  bool get isFixed => mode == 'FIXED';
  bool get isZoneBased => mode == 'ZONE_BASED';
  bool get isPlatform => mode == 'PLATFORM';
}
