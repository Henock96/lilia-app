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
      id: json['id'],
      userId: json['userId'],
      items: (json['items'] as List)
          .map((itemJson) => CartItem.fromMap(itemJson))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
  }) =>
      CartItem(
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
    id: json["id"],
    cartId: json["cartId"],
    productId: json["productId"],
    variantId: json["variantId"],
    menuId: json["menuId"],
    quantite: json["quantite"],
    createdAt: DateTime.parse(json["createdAt"]),
    product: ProductItem.fromMap(json["product"]),
    variant: VariantItem.fromMap(json["variant"]),
    menu: json["menu"] != null ? MenuInfo.fromMap(json["menu"]) : null,
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
    id: json["id"],
    nom: json["nom"],
    prix: (json["prix"] as num).toDouble(),
    imageUrl: json["imageUrl"],
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

  ProductItem({
    required this.nom,
    this.imageUrl,
    required this.restaurantId,
  });

  ProductItem copyWith({
    String? nom,
    String? imageUrl,
    String? restaurantId,
  }) =>
      ProductItem(
        nom: nom ?? this.nom,
        imageUrl: imageUrl ?? this.imageUrl,
        restaurantId: restaurantId ?? this.restaurantId,
      );

  factory ProductItem.fromMap(Map<String, dynamic> json) => ProductItem(
    nom: json["nom"],
    imageUrl: json["imageUrl"],
    restaurantId: json["restaurantId"],
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

  VariantItem({
    required this.label,
    required this.prix,
  });

  VariantItem copyWith({
    String? label,
    int? prix,
  }) =>
      VariantItem(
        label: label ?? this.label,
        prix: prix ?? this.prix,
      );

  factory VariantItem.fromMap(Map<String, dynamic> json) => VariantItem(
    label: json["label"],
    prix: json["prix"],
  );

  Map<String, dynamic> toMap() => {
    "label": label,
    "prix": prix,
  };
}
