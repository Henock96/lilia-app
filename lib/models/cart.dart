import 'package:lilia_app/models/modifier.dart';
import 'package:lilia_app/utils/currency.dart';

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<dynamic> _asList(Object? value) => value is List ? value : <dynamic>[];

String _asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

int _asInt(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

DateTime _asDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

class Cart {
  final String id;
  final String userId;
  final List<CartItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cart({
    required this.id,
    required this.userId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  Cart copyWith({
    String? id,
    String? userId,
    List<CartItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Cart(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    items: items ?? this.items,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Items individuels (sans menuId)
  List<CartItem> get individualItems =>
      items.where((item) => item.menuId == null).toList();

  /// Items groupés par menuId
  Map<String, List<CartItem>> get menuGroups {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      if (item.menuId != null) {
        map.putIfAbsent(item.menuId!, () => []);
        map[item.menuId!]!.add(item);
      }
    }
    return map;
  }

  // Calcule le nombre total d'articles dans le panier
  int get totalItems {
    if (items.isEmpty) return 0;
    // Compter les items individuels normalement
    int count = individualItems.fold(0, (total, item) => total + item.quantite);
    // Compter chaque menu comme 1 unité * quantité
    for (final entry in menuGroups.entries) {
      count += entry.value.first.quantite;
    }
    return count;
  }

  // Calcule le prix total du panier
  //
  // F3-09 — le prix d'une ligne individuelle est son **prix unitaire serveur**
  // (`unitPriceXaf` : variante + options), jamais `variant.prix` seul, qui
  // sous-estimerait tout article à supplément. Multiplier par la quantité
  // locale garde l'affichage juste pendant une mise à jour optimiste ; le
  // checkout, lui, recalcule tout.
  double get totalPrice {
    if (items.isEmpty) return 0.0;
    // Prix des items individuels
    double total = individualItems.fold(
      0.0,
      (sum, item) => sum + (item.unitPrice.toDouble() * item.quantite),
    );
    // Prix des menus (prix du menu * quantité)
    for (final entry in menuGroups.entries) {
      final groupItems = entry.value;
      if (groupItems.isNotEmpty && groupItems.first.menu != null) {
        total += groupItems.first.menu!.prix * groupItems.first.quantite;
      }
    }
    return total;
  }

  // Prix total formaté
  String get formattedTotalPrice {
    return formatPrice(totalPrice);
  }

  /// Multi-vendeurs (LIL-122) : vrai si AU MOINS un item du panier est
  /// `madeToOrder=true`. Drive le flux checkout (date picker requis,
  /// disclaimer paiement, etc.). Backend rejette les paniers mixtes,
  /// donc en pratique tout ou rien — mais ce getter reste tolérant.
  bool get hasMadeToOrderItems => items.any((item) => item.product.madeToOrder);

  /// Vrai si le panier est 100% madeToOrder ET non vide (= preorder pur).
  bool get isPreorderCart =>
      items.isNotEmpty && items.every((item) => item.product.madeToOrder);

  /// F3-09 — au moins une ligne ne passera pas le checkout telle quelle
  /// (option en rupture, choix devenu obligatoire). Annoncé par le serveur.
  bool get hasIssues => items.any((item) => item.issue != null);

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: _asString(json['id']),
      userId: _asString(json['userId']),
      items: _asList(
        json['items'],
      ).whereType<Map<String, dynamic>>().map(CartItem.fromMap).toList(),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }
}

class CartItem {
  String id;
  String cartId;
  String productId;
  String variantId;
  String? menuId;
  int quantite;
  DateTime createdAt;
  ProductItem product;
  VariantItem variant;
  MenuInfo? menu;

  /// F3-09 — sélection d'options, forme canonique du serveur (`''` = aucune).
  /// Fait partie de l'identité de la ligne.
  String optionsSignature;

  /// F3-09 — options de la ligne (groupe, nom, supplément unitaire, quantité).
  List<LineOption> options;

  /// F3-09 — prix unitaire calculé par le serveur (variante + options).
  /// `null` pour une ligne locale (panier invité, affichage optimiste) : voir
  /// [unitPrice].
  int? unitPriceXaf;

  /// F3-09 — la ligne n'est plus commandable telle quelle (`GET /cart`).
  LineIssue? issue;

  CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.variantId,
    this.menuId,
    required this.quantite,
    required this.createdAt,
    required this.product,
    required this.variant,
    this.menu,
    this.optionsSignature = '',
    this.options = const [],
    this.unitPriceXaf,
    this.issue,
  });

  /// Part des options dans le prix unitaire.
  int get optionsTotal =>
      options.fold(0, (sum, o) => sum + o.priceDeltaXaf * o.quantity);

  /// Prix unitaire affiché : celui du **serveur** quand il est connu ; sinon
  /// (ligne locale pas encore confirmée) variante + suppléments du catalogue,
  /// remplacé dès la réponse du serveur.
  int get unitPrice => unitPriceXaf ?? (variant.prix + optionsTotal);

  CartItem copyWith({
    String? id,
    String? cartId,
    String? productId,
    String? variantId,
    String? menuId,
    int? quantite,
    DateTime? createdAt,
    ProductItem? product,
    VariantItem? variant,
    MenuInfo? menu,
    String? optionsSignature,
    List<LineOption>? options,
    int? unitPriceXaf,
    LineIssue? issue,
  }) => CartItem(
    id: id ?? this.id,
    cartId: cartId ?? this.cartId,
    productId: productId ?? this.productId,
    variantId: variantId ?? this.variantId,
    menuId: menuId ?? this.menuId,
    quantite: quantite ?? this.quantite,
    createdAt: createdAt ?? this.createdAt,
    product: product ?? this.product,
    variant: variant ?? this.variant,
    menu: menu ?? this.menu,
    optionsSignature: optionsSignature ?? this.optionsSignature,
    options: options ?? this.options,
    unitPriceXaf: unitPriceXaf ?? this.unitPriceXaf,
    issue: issue ?? this.issue,
  );

  factory CartItem.fromMap(Map<String, dynamic> json) => CartItem(
    id: _asString(json["id"]),
    cartId: _asString(json["cartId"]),
    productId: _asString(json["productId"]),
    variantId: _asString(json["variantId"]),
    menuId: json["menuId"] is String ? json["menuId"] as String : null,
    quantite: _asInt(json["quantite"]),
    createdAt: _asDate(json["createdAt"]),
    product: ProductItem.fromMap(_asMap(json["product"])),
    variant: VariantItem.fromMap(_asMap(json["variant"])),
    menu: json["menu"] is Map<String, dynamic>
        ? MenuInfo.fromMap(json["menu"] as Map<String, dynamic>)
        : null,
    // F3-09 — absents d'un serveur ou d'un panier invité antérieurs : ligne
    // sans option, prix unitaire recalculé localement pour l'affichage.
    optionsSignature: _asString(json["optionsSignature"]),
    options: LineOption.listFrom(json["options"]),
    unitPriceXaf: json["unitPriceXaf"] is num
        ? (json["unitPriceXaf"] as num).toInt()
        : null,
    issue: LineIssue.from(json["issue"]),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "cartId": cartId,
    "productId": productId,
    "variantId": variantId,
    "menuId": menuId,
    "quantite": quantite,
    "createdAt": createdAt.toIso8601String(),
    "product": product.toMap(),
    "variant": variant.toMap(),
    "menu": menu?.toMap(),
    // F3-09 — le panier invité doit garder les options : sans elles, la
    // reprise à la connexion ajouterait « Poulet » au lieu de « Poulet +
    // Alloco » (ou serait refusée pour choix obligatoire manquant).
    "optionsSignature": optionsSignature,
    "options": options.map((o) => o.toMap()).toList(),
    "unitPriceXaf": unitPriceXaf,
  };
}

class MenuInfo {
  String id;
  String nom;
  double prix;
  String? imageUrl;

  MenuInfo({
    required this.id,
    required this.nom,
    required this.prix,
    this.imageUrl,
  });

  factory MenuInfo.fromMap(Map<String, dynamic> json) => MenuInfo(
    id: _asString(json["id"]),
    nom: _asString(json["nom"], 'Menu'),
    prix: (json["prix"] as num?)?.toDouble() ?? 0,
    imageUrl: json["imageUrl"] is String ? json["imageUrl"] as String : null,
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "nom": nom,
    "prix": prix,
    "imageUrl": imageUrl,
  };
}

class ProductItem {
  String nom;
  String? imageUrl;
  String restaurantId;
  // Multi-vendeurs (LIL-122) — drive le flux preorder côté UI.
  bool madeToOrder;

  ProductItem({
    required this.nom,
    this.imageUrl,
    required this.restaurantId,
    this.madeToOrder = false,
  });

  ProductItem copyWith({
    String? nom,
    String? imageUrl,
    String? restaurantId,
    bool? madeToOrder,
  }) => ProductItem(
    nom: nom ?? this.nom,
    imageUrl: imageUrl ?? this.imageUrl,
    restaurantId: restaurantId ?? this.restaurantId,
    madeToOrder: madeToOrder ?? this.madeToOrder,
  );

  factory ProductItem.fromMap(Map<String, dynamic> json) => ProductItem(
    nom: _asString(json["nom"], 'Produit'),
    imageUrl: json["imageUrl"] is String ? json["imageUrl"] as String : null,
    restaurantId: _asString(json["restaurantId"]),
    madeToOrder: json["madeToOrder"] == true,
  );

  Map<String, dynamic> toMap() => {
    "nom": nom,
    "imageUrl": imageUrl,
    "restaurantId": restaurantId,
    "madeToOrder": madeToOrder,
  };
}

class VariantItem {
  String label;
  int prix;

  VariantItem({required this.label, required this.prix});

  VariantItem copyWith({String? label, int? prix}) =>
      VariantItem(label: label ?? this.label, prix: prix ?? this.prix);

  factory VariantItem.fromMap(Map<String, dynamic> json) => VariantItem(
    label: _asString(json["label"], 'Standard'),
    prix: _asInt(json["prix"]),
  );

  Map<String, dynamic> toMap() => {"label": label, "prix": prix};
}
