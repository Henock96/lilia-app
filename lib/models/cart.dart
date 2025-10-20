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

  // Calcule le nombre total d'articles dans le panier
  int get totalItems {
    if (items.isEmpty) {
      return 0;
    }
    return items.fold(0, (total, item) => total + item.quantite);
  }

  // Calcule le prix total du panier
  double get totalPrice {
    if (items.isEmpty) {
      return 0.0;
    }
    return items.fold(0.0, (total, item) => total + (item.variant.prix.toDouble() * item.quantite));
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
  int quantite;
  DateTime createdAt;
  ProductItem product;
  VariantItem variant;

  CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.variantId,
    required this.quantite,
    required this.createdAt,
    required this.product,
    required this.variant,
  });

  CartItem copyWith({
    String? id,
    String? cartId,
    String? productId,
    String? variantId,
    int? quantite,
    DateTime? createdAt,
    ProductItem? product,
    VariantItem? variant,
  }) =>
      CartItem(
        id: id ?? this.id,
        cartId: cartId ?? this.cartId,
        productId: productId ?? this.productId,
        variantId: variantId ?? this.variantId,
        quantite: quantite ?? this.quantite,
        createdAt: createdAt ?? this.createdAt,
        product: product ?? this.product,
        variant: variant ?? this.variant,
      );

  factory CartItem.fromMap(Map<String, dynamic> json) => CartItem(
    id: json["id"],
    cartId: json["cartId"],
    productId: json["productId"],
    variantId: json["variantId"],
    quantite: json["quantite"],
    createdAt: DateTime.parse(json["createdAt"]),
    product: ProductItem.fromMap(json["product"]),
    variant: VariantItem.fromMap(json["variant"]),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "cartId": cartId,
    "productId": productId,
    "variantId": variantId,
    "quantite": quantite,
    "createdAt": createdAt.toIso8601String(),
    "product": product.toMap(),
    "variant": variant.toMap(),
  };
}

class ProductItem {
  String nom;
  String imageUrl;
  String restaurantId;

  ProductItem({
    required this.nom,
    required this.imageUrl,
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