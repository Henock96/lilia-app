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
  double get totalPrice {
    if (items.isEmpty) return 0.0;
    // Prix des items individuels
    double total = individualItems.fold(
      0.0,
      (sum, item) => sum + (item.variant.prix.toDouble() * item.quantite),
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
    return '${totalPrice.toStringAsFixed(0)} FCFA';
  }

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
  });

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

  ProductItem({required this.nom, this.imageUrl, required this.restaurantId});

  ProductItem copyWith({String? nom, String? imageUrl, String? restaurantId}) =>
      ProductItem(
        nom: nom ?? this.nom,
        imageUrl: imageUrl ?? this.imageUrl,
        restaurantId: restaurantId ?? this.restaurantId,
      );

  factory ProductItem.fromMap(Map<String, dynamic> json) => ProductItem(
    nom: _asString(json["nom"], 'Produit'),
    imageUrl: json["imageUrl"] is String ? json["imageUrl"] as String : null,
    restaurantId: _asString(json["restaurantId"]),
  );

  Map<String, dynamic> toMap() => {
    "nom": nom,
    "imageUrl": imageUrl,
    "restaurantId": restaurantId,
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
