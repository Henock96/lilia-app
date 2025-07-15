class Adresse {
  final String id;
  final String rue;
  final String ville;
  final String? etat;
  final String country;
  final String userId;

  Adresse({
    required this.id,
    required this.rue,
    required this.ville,
    this.etat,
    required this.country,
    required this.userId,
  });

  factory Adresse.fromJson(Map<String, dynamic> json) {
    return Adresse(
      id: json['id'],
      rue: json['rue'],
      ville: json['ville'],
      etat: json['etat'],
      country: json['country'],
      userId: json['userId'],
    );
  }

  // Pour l'affichage
  @override
  String toString() {
    return '$rue, $ville';
  }
}
