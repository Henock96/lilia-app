
import 'package:lilia_app/models/restaurant.dart';

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
  });

  bool get isAvailable => stockRestant == null || stockRestant! > 0;

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