/// Offre boutique en cours chez un vendeur (F3-11) — `activeOffer` des
/// lectures publiques (`GET /vendors`, `GET /vendors/:id`, `GET /restaurants`).
///
/// Financée par le vendeur, appliquée d'elle-même au panier. Le montant exact
/// d'une commande vient du devis serveur (`POST /orders/quote`) : ce modèle
/// ne sert qu'à l'afficher (badge « −10 % », libellé).
class ActiveOffer {
  const ActiveOffer({
    required this.id,
    required this.kind,
    required this.value,
    required this.label,
    this.minSubTotalXaf = 0,
    this.maxDiscountXaf,
    this.endsAt,
  });

  final String id;

  /// `PERCENT` ou `FIXED_THRESHOLD`.
  final String kind;
  final int value;

  /// Écrit par le serveur : « −10 % sur toute la boutique ».
  final String label;
  final int minSubTotalXaf;
  final int? maxDiscountXaf;
  final DateTime? endsAt;

  bool get isPercent => kind == 'PERCENT';

  /// Texte court du badge : « −10 % » ou « −500 F ».
  String get badge => isPercent ? '−$value %' : '−$value F';

  /// `null` pour une réponse sans offre, un serveur antérieur, ou une forme
  /// inattendue — l'absence d'offre ne doit jamais casser une carte vendeur.
  static ActiveOffer? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final value = json['value'];
    if (id is! String || value is! num) return null;
    return ActiveOffer(
      id: id,
      kind: json['kind'] as String? ?? 'PERCENT',
      value: value.toInt(),
      label: json['label'] as String? ?? '',
      minSubTotalXaf: (json['minSubTotalXaf'] as num?)?.toInt() ?? 0,
      maxDiscountXaf: (json['maxDiscountXaf'] as num?)?.toInt(),
      endsAt: DateTime.tryParse(json['endsAt'] as String? ?? ''),
    );
  }
}
