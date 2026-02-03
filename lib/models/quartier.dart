class Quartier {
  final String id;
  final String nom;
  final String ville;

  Quartier({
    required this.id,
    required this.nom,
    required this.ville,
  });

  factory Quartier.fromJson(Map<String, dynamic> json) {
    return Quartier(
      id: json['id'] as String,
      nom: json['nom'] as String,
      ville: json['ville'] as String? ?? 'Brazzaville',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'ville': ville,
    };
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
  final double fee;
  final String? zoneName;
  final String? quartierName;
  final bool isDefaultZone;

  DeliveryFeeResult({
    required this.mode,
    required this.fee,
    this.zoneName,
    this.quartierName,
    this.isDefaultZone = false,
  });

  factory DeliveryFeeResult.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeResult(
      mode: json['mode'] as String,
      fee: (json['fee'] as num).toDouble(),
      zoneName: json['zoneName'] as String?,
      quartierName: json['quartierName'] as String?,
      isDefaultZone: json['isDefaultZone'] as bool? ?? false,
    );
  }

  bool get isFixed => mode == 'FIXED';
  bool get isZoneBased => mode == 'ZONE_BASED';
}
