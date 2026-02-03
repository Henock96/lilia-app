import 'package:lilia_app/models/quartier.dart';

class Adresse {
  final String id;
  final String rue;
  final String ville;
  final String? etat;
  final String country;
  final String userId;
  final String? quartierId;
  final Quartier? quartier;

  Adresse({
    required this.id,
    required this.rue,
    required this.ville,
    this.etat,
    required this.country,
    required this.userId,
    this.quartierId,
    this.quartier,
  });

  factory Adresse.fromJson(Map<String, dynamic> json) {
    return Adresse(
      id: json['id'],
      rue: json['rue'],
      ville: json['ville'],
      etat: json['etat'],
      country: json['country'],
      userId: json['userId'],
      quartierId: json['quartierId'],
      quartier: json['quartier'] != null
          ? Quartier.fromJson(json['quartier'])
          : null,
    );
  }

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
