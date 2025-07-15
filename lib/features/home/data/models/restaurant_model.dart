// To parse this JSON data, do
//
//     final restaurant = restaurantFromMap(jsonString);

import 'dart:convert';

Restaurant restaurantFromMap(String str) => Restaurant.fromMap(json.decode(str));

String restaurantToMap(Restaurant data) => json.encode(data.toMap());

class Restaurant {
  String? id;
  String? nom;
  String? adresse;
  String? phone;
  String? imageUrl;
  String? ownerId;
  DateTime? createdAt;
  DateTime? updatedAt;
  List<Product>? products;

  Restaurant({
    this.id,
    this.nom,
    this.adresse,
    this.phone,
    this.imageUrl,
    this.ownerId,
    this.createdAt,
    this.updatedAt,
    this.products,
  });

  Restaurant copyWith({
    String? id,
    String? nom,
    String? adresse,
    String? phone,
    String? imageUrl,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Product>? products,
  }) =>
      Restaurant(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        adresse: adresse ?? this.adresse,
        phone: phone ?? this.phone,
        imageUrl: imageUrl ?? this.imageUrl,
        ownerId: ownerId ?? this.ownerId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        products: products ?? this.products,
      );

  factory Restaurant.fromMap(Map<String, dynamic> json) => Restaurant(
    id: json["id"],
    nom: json["nom"],
    adresse: json["adresse"],
    phone: json["phone"],
    imageUrl: json["imageUrl"],
    ownerId: json["ownerId"],
    createdAt: json["createdAt"] == null ? null : DateTime.parse(json["createdAt"]),
    updatedAt: json["updatedAt"] == null ? null : DateTime.parse(json["updatedAt"]),
    products: json["products"] == null ? [] : List<Product>.from(json["products"]!.map((x) => Product.fromMap(x))),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "nom": nom,
    "adresse": adresse,
    "phone": phone,
    "imageUrl": imageUrl,
    "ownerId": ownerId,
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
    "products": products == null ? [] : List<dynamic>.from(products!.map((x) => x.toMap())),
  };
}

class Product {
  String? id;
  String? nom;
  String? description;
  String? imageUrl;
  int? prixOriginal;
  String? restaurantId;
  String? categoryId;
  DateTime? createdAt;
  DateTime? updatedAt;
  Category? category;
  List<Variant>? variants;

  Product({
    this.id,
    this.nom,
    this.description,
    this.imageUrl,
    this.prixOriginal,
    this.restaurantId,
    this.categoryId,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.variants,
  });

  Product copyWith({
    String? id,
    String? nom,
    String? description,
    String? imageUrl,
    int? prixOriginal,
    String? restaurantId,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Category? category,
    List<Variant>? variants,
  }) =>
      Product(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        prixOriginal: prixOriginal ?? this.prixOriginal,
        restaurantId: restaurantId ?? this.restaurantId,
        categoryId: categoryId ?? this.categoryId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        category: category ?? this.category,
        variants: variants ?? this.variants,
      );

  factory Product.fromMap(Map<String, dynamic> json) => Product(
    id: json["id"],
    nom: json["nom"],
    description: json["description"],
    imageUrl: json["imageUrl"],
    prixOriginal: json["prixOriginal"],
    restaurantId: json["restaurantId"],
    categoryId: json["categoryId"],
    createdAt: json["createdAt"] == null ? null : DateTime.parse(json["createdAt"]),
    updatedAt: json["updatedAt"] == null ? null : DateTime.parse(json["updatedAt"]),
    category: json["category"] == null ? null : Category.fromMap(json["category"]),
    variants: json["variants"] == null ? [] : List<Variant>.from(json["variants"]!.map((x) => Variant.fromMap(x))),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "nom": nom,
    "description": description,
    "imageUrl": imageUrl,
    "prixOriginal": prixOriginal,
    "restaurantId": restaurantId,
    "categoryId": categoryId,
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
    "category": category?.toMap(),
    "variants": variants == null ? [] : List<dynamic>.from(variants!.map((x) => x.toMap())),
  };
}

class Category {
  String? id;
  String? nom;
  DateTime? createdAt;
  DateTime? updatedAt;

  Category({
    this.id,
    this.nom,
    this.createdAt,
    this.updatedAt,
  });

  Category copyWith({
    String? id,
    String? nom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Category(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Category.fromMap(Map<String, dynamic> json) => Category(
    id: json["id"],
    nom: json["nom"],
    createdAt: json["createdAt"] == null ? null : DateTime.parse(json["createdAt"]),
    updatedAt: json["updatedAt"] == null ? null : DateTime.parse(json["updatedAt"]),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "nom": nom,
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
  };
}

class Variant {
  String? id;
  String? label;
  int? prix;
  String? productId;
  DateTime? createdAt;
  DateTime? updatedAt;

  Variant({
    this.id,
    this.label,
    this.prix,
    this.productId,
    this.createdAt,
    this.updatedAt,
  });

  Variant copyWith({
    String? id,
    String? label,
    int? prix,
    String? productId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Variant(
        id: id ?? this.id,
        label: label ?? this.label,
        prix: prix ?? this.prix,
        productId: productId ?? this.productId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Variant.fromMap(Map<String, dynamic> json) => Variant(
    id: json["id"],
    label: json["label"],
    prix: json["prix"],
    productId: json["productId"],
    createdAt: json["createdAt"] == null ? null : DateTime.parse(json["createdAt"]),
    updatedAt: json["updatedAt"] == null ? null : DateTime.parse(json["updatedAt"]),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "label": label,
    "prix": prix,
    "productId": productId,
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
  };
}
