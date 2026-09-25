/// F3-09 — options & suppléments d'un produit (« accompagnement au choix »,
/// « + œuf 300 »), tels que la carte les sert.
///
/// ## Ce que l'application calcule, et ce qu'elle ne calcule pas
///
/// Le serveur est l'autorité : il valide la sélection (`POST /cart/add`), la
/// revalide au checkout et chiffre chaque ligne (`unitPriceXaf`). Ici, on ne
/// fait que l'**ergonomie** : désactiver « Ajouter » tant qu'un groupe
/// obligatoire est vide, et afficher un prix avant que le serveur ait répondu.
/// Un refus du serveur fait toujours foi — il est affiché tel quel.
library;

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<dynamic> _asList(Object? value) => value is List ? value : <dynamic>[];

String _asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

int _asInt(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

/// Une option de la carte (« Alloco », « Œuf +300 »).
class ModifierOption {
  final String id;
  final String name;
  final int priceDeltaXaf;
  final int maxQuantity;

  /// Rupture du jour : affichée grisée, jamais sélectionnable.
  final bool isAvailable;

  const ModifierOption({
    required this.id,
    required this.name,
    this.priceDeltaXaf = 0,
    this.maxQuantity = 1,
    this.isAvailable = true,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) => ModifierOption(
    id: _asString(json['id']),
    name: _asString(json['name'], 'Option'),
    priceDeltaXaf: _asInt(json['priceDeltaXaf']),
    maxQuantity: _asInt(json['maxQuantity'], 1),
    isAvailable: json['isAvailable'] != false,
  );
}

/// Un groupe d'options (« Accompagnement », obligatoire, 1 choix).
class ModifierGroup {
  final String id;
  final String name;

  /// Options **distinctes** minimum (≥ 1 = obligatoire).
  final int minSelect;

  /// Options **distinctes** maximum (1 = choix unique, rendu en radio).
  final int maxSelect;
  final List<ModifierOption> options;

  const ModifierGroup({
    required this.id,
    required this.name,
    this.minSelect = 0,
    this.maxSelect = 1,
    this.options = const [],
  });

  bool get isRequired => minSelect >= 1;
  bool get isSingleChoice => maxSelect == 1;

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
    id: _asString(json['id']),
    name: _asString(json['name'], 'Options'),
    minSelect: _asInt(json['minSelect']),
    maxSelect: _asInt(json['maxSelect'], 1),
    options: _asList(json['options'])
        .whereType<Map<String, dynamic>>()
        .map(ModifierOption.fromJson)
        .toList(),
  );

  /// Absent des réponses antérieures à F3-09 (ou interrupteur éteint) : vide.
  static List<ModifierGroup> listFrom(Object? value) => _asList(value)
      .whereType<Map<String, dynamic>>()
      .map(ModifierGroup.fromJson)
      .toList();
}

/// Une option choisie, telle qu'elle part au serveur — ni prix ni nom : le
/// serveur les relit au catalogue.
class SelectedOption {
  final String optionId;
  final int quantity;

  const SelectedOption({required this.optionId, this.quantity = 1});

  Map<String, dynamic> toJson() => {'optionId': optionId, 'quantity': quantity};

  factory SelectedOption.fromJson(Map<String, dynamic> json) => SelectedOption(
    optionId: _asString(json['optionId']),
    quantity: _asInt(json['quantity'], 1),
  );
}

/// Clé d'identité **locale** d'une sélection — même forme que la signature du
/// serveur (`optionId:quantité` triés, joints par `,`), pour fusionner les
/// lignes du panier invité et de l'affichage optimiste comme le fera le
/// serveur. Ce n'est jamais elle qui fait foi : la réponse du serveur remplace
/// le panier entier.
String selectionKey(Iterable<SelectedOption> selection) {
  final sorted = [...selection]..sort((a, b) => a.optionId.compareTo(b.optionId));
  return sorted.map((s) => '${s.optionId}:${s.quantity}').join(',');
}

/// Une option d'une ligne de panier ou de commande, telle que le serveur la
/// décrit (nom du groupe, nom de l'option, supplément unitaire, quantité).
class LineOption {
  final String optionId;
  final String groupName;
  final String name;
  final int priceDeltaXaf;
  final int quantity;

  const LineOption({
    required this.optionId,
    required this.groupName,
    required this.name,
    this.priceDeltaXaf = 0,
    this.quantity = 1,
  });

  /// Panier (`name`) ou commande (`optionName`) : deux contrats, une lecture.
  factory LineOption.fromJson(Map<String, dynamic> json) => LineOption(
    optionId: _asString(json['optionId']),
    groupName: _asString(json['groupName']),
    name: _asString(json['name'], _asString(json['optionName'], 'Option')),
    priceDeltaXaf: _asInt(json['priceDeltaXaf']),
    quantity: _asInt(json['quantity'], 1),
  );

  Map<String, dynamic> toMap() => {
    'optionId': optionId,
    'groupName': groupName,
    'name': name,
    'priceDeltaXaf': priceDeltaXaf,
    'quantity': quantity,
  };

  SelectedOption get selected =>
      SelectedOption(optionId: optionId, quantity: quantity);

  /// « Œuf ×2 » — le supplément est affiché à part, par la ligne.
  String get label => quantity > 1 ? '$name ×$quantity' : name;

  static List<LineOption> listFrom(Object? value) => _asList(value)
      .whereType<Map<String, dynamic>>()
      .map(LineOption.fromJson)
      .toList();
}

/// Problème d'une ligne de panier annoncé par le serveur (`GET /cart`) :
/// l'option est en rupture, un choix est devenu obligatoire… Le checkout la
/// refusera telle quelle.
class LineIssue {
  final String code;
  final String message;

  const LineIssue({required this.code, required this.message});

  static LineIssue? from(Object? value) {
    final map = _asMap(value);
    if (map.isEmpty) return null;
    return LineIssue(
      code: _asString(map['code'], 'UNKNOWN'),
      message: _asString(map['message'], 'Cet article est à revoir.'),
    );
  }

  Map<String, dynamic> toMap() => {'code': code, 'message': message};
}
