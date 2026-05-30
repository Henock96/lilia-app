
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double prixOriginal;
  final String? imageUrl;
  final String restaurantId;
  final String categoryId;
  final Category? category;
  final List<ProductVariant> variants;
  final int? stockRestant;
  final int? orderCount;
  final String? restaurantName;
  final String? restaurantImageUrl;
  final bool? restaurantIsOpen;
  final VendorType? restaurantVendorType;

  // Multi-vendeurs (LIL-117)
  final ProductType productType;
  final StockMode stockMode;
  final String? ingredients;
  final int? shelfLifeDays;
  final bool madeToOrder;
  final String? availableFrom; // HH:mm
  final String? availableUntil; // HH:mm

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.prixOriginal,
    this.imageUrl,
    required this.restaurantId,
    required this.categoryId,
    this.category,
    required this.variants,
    this.stockRestant,
    this.orderCount,
    this.restaurantName,
    this.restaurantImageUrl,
    this.restaurantIsOpen,
    this.restaurantVendorType,
    this.productType = ProductType.FOOD,
    this.stockMode = StockMode.DAILY,
    this.ingredients,
    this.shelfLifeDays,
    this.madeToOrder = false,
    this.availableFrom,
    this.availableUntil,
  });

  bool get isAvailable => stockRestant == null || stockRestant! > 0;

  /// Vrai si le produit a une fenêtre horaire et que l'heure actuelle est
  /// dans cette fenêtre. Si pas de fenêtre, toujours vrai (pas de contrainte).
  bool get isWithinAvailabilityWindow {
    if (availableFrom == null || availableUntil == null) return true;
    final now = DateTime.now();
    final current = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return current.compareTo(availableFrom!) >= 0 &&
        current.compareTo(availableUntil!) <= 0;
  }

  /// Prix d'affichage (premier variant ou prix original)
  double get displayPrice {
    if (variants.isNotEmpty) return variants.first.prix;
    return prixOriginal;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    var variantsList = json['variants'] as List;
    List<ProductVariant> variants =
    variantsList.map((i) => ProductVariant.fromJson(i)).toList();

    return Product(
      id: json['id'],
      name: json['nom'],
      description: json['description'] ?? '',
      prixOriginal: (json['prixOriginal'] as num).toDouble(),
      imageUrl: json['imageUrl'],
      restaurantId: json['restaurantId'],
      categoryId: json['categoryId'],
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
      variants: variants,
      stockRestant: json['stockRestant'] as int?,
      orderCount: json['orderCount'] as int?,
      restaurantName: json['restaurant']?['nom'] as String?,
      restaurantImageUrl: json['restaurant']?['imageUrl'] as String?,
      restaurantIsOpen: json['restaurant']?['isOpen'] as bool?,
      restaurantVendorType: json['restaurant']?['vendorType'] != null
          ? VendorType.fromString(json['restaurant']['vendorType'] as String?)
          : null,
      productType: ProductType.fromString(json['productType'] as String?),
      stockMode: StockMode.fromString(json['stockMode'] as String?),
      ingredients: json['ingredients'] as String?,
      shelfLifeDays: json['shelfLifeDays'] as int?,
      madeToOrder: json['madeToOrder'] ?? false,
      availableFrom: json['availableFrom'] as String?,
      availableUntil: json['availableUntil'] as String?,
    );
  }
}

class ProductVariant {
  final String id;
  final String label;
  final double prix; // Correspond à 'prix' du variant

  ProductVariant({
    required this.id,
    required this.label,
    required this.prix,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'],
      label: json['label'],
      prix: (json['prix'] as num).toDouble(),
    );
  }
}