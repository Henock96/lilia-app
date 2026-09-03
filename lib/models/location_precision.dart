/// Fiabilité d'une position de livraison — miroir de l'enum backend
/// `LocationPrecision` (Prisma).
///
/// Trois valeurs, parce que ce sont les trois seules situations qui appellent
/// une **conduite différente** de l'interface : afficher un marqueur, afficher
/// un marqueur avec une réserve, ou n'afficher aucun marqueur.
enum LocationPrecision {
  /// Point posé par le client sur la carte. On peut s'y fier.
  exact,

  /// Centroïde du quartier, faute de mieux. Bon à l'échelle du quartier, faux
  /// à l'échelle de la rue. ⚠️ Ne jamais l'afficher comme une position exacte.
  approximate,

  /// Aucune coordonnée. On n'affiche **aucun** marqueur : un faux point est
  /// pire que pas de point, parce qu'on s'y rend.
  unknown;

  /// Valeur sérialisée côté backend.
  String get wireValue => switch (this) {
    LocationPrecision.exact => 'EXACT',
    LocationPrecision.approximate => 'APPROXIMATE',
    LocationPrecision.unknown => 'UNKNOWN',
  };

  /// Parse une valeur backend.
  ///
  /// Toute valeur inconnue — y compris `null`, renvoyé par une version du
  /// backend antérieure à ce champ — devient `unknown`. C'est le repli sûr :
  /// il fait taire la carte au lieu de la faire mentir.
  static LocationPrecision fromWire(String? value) => switch (value) {
    'EXACT' => LocationPrecision.exact,
    'APPROXIMATE' => LocationPrecision.approximate,
    _ => LocationPrecision.unknown,
  };

  /// `true` si un marqueur peut être posé sur la carte.
  bool get hasPosition => this != LocationPrecision.unknown;

  /// `true` si l'interface doit accompagner le marqueur d'une réserve.
  bool get needsWarning => this == LocationPrecision.approximate;
}
