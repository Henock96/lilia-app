// To parse this JSON data, do
//
//     final restaurant = restaurantFromMap(jsonString);

import 'dart:convert';

Restaurant restaurantFromMap(String str) =>
    Restaurant.fromMap(json.decode(str) as Map<String, dynamic>);

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
  }) => Restaurant(
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
    id: json["id"] as String?,
    nom: json["nom"] as String?,
    adresse: json["adresse"] as String?,
    phone: json["phone"] as String?,
    imageUrl: json["imageUrl"] as String?,
    ownerId: json["ownerId"] as String?,
    createdAt: json["createdAt"] == null
        ? null
        : DateTime.parse(json["createdAt"] as String),
    updatedAt: json["updatedAt"] == null
        ? null
        : DateTime.parse(json["updatedAt"] as String),
    products: json["products"] == null
        ? []
        : List<Product>.from(
            (json["products"] as List<dynamic>).map(
              (x) => Product.fromMap(x as Map<String, dynamic>),
            ),
          ),
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
    "products": products == null
        ? <dynamic>[]
        : List<dynamic>.from(products!.map((x) => x.toMap())),
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
  }) => Product(
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
    id: json["id"] as String?,
    nom: json["nom"] as String?,
    description: json["description"] as String?,
    imageUrl: json["imageUrl"] as String?,
    prixOriginal: json["prixOriginal"] as int?,
    restaurantId: json["restaurantId"] as String?,
    categoryId: json["categoryId"] as String?,
    createdAt: json["createdAt"] == null
        ? null
        : DateTime.parse(json["createdAt"] as String),
    updatedAt: json["updatedAt"] == null
        ? null
        : DateTime.parse(json["updatedAt"] as String),
    category: json["category"] == null
        ? null
        : Category.fromMap(json["category"] as Map<String, dynamic>),
    variants: json["variants"] == null
        ? []
        : List<Variant>.from(
            (json["variants"] as List<dynamic>).map(
              (x) => Variant.fromMap(x as Map<String, dynamic>),
            ),
          ),
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
    "variants": variants == null
        ? <dynamic>[]
        : List<dynamic>.from(variants!.map((x) => x.toMap())),
  };
}

class Category {
  String? id;
  String? nom;
  DateTime? createdAt;
  DateTime? updatedAt;

  Category({this.id, this.nom, this.createdAt, this.updatedAt});

  Category copyWith({
    String? id,
    String? nom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Category(
    id: id ?? this.id,
    nom: nom ?? this.nom,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Category.fromMap(Map<String, dynamic> json) => Category(
    id: json["id"] as String?,
    nom: json["nom"] as String?,
    createdAt: json["createdAt"] == null
        ? null
        : DateTime.parse(json["createdAt"] as String),
    updatedAt: json["updatedAt"] == null
        ? null
        : DateTime.parse(json["updatedAt"] as String),
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
  }) => Variant(
    id: id ?? this.id,
    label: label ?? this.label,
    prix: prix ?? this.prix,
    productId: productId ?? this.productId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Variant.fromMap(Map<String, dynamic> json) => Variant(
    id: json["id"] as String?,
    label: json["label"] as String?,
    prix: json["prix"] as int?,
    productId: json["productId"] as String?,
    createdAt: json["createdAt"] == null
        ? null
        : DateTime.parse(json["createdAt"] as String),
    updatedAt: json["updatedAt"] == null
        ? null
        : DateTime.parse(json["updatedAt"] as String),
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
