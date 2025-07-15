
import 'package:lilia_app/models/restaurant.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double prixOriginal; // Correspond à 'prixOriginal' de votre JSON
  final String imageUrl;
  final String restaurantId;
  final String categoryId;
  final Category? category; // La catégorie est maintenant imbriquée
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.prixOriginal,
    required this.imageUrl,
    required this.restaurantId,
    required this.categoryId,
    this.category,
    required this.variants,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    var variantsList = json['variants'] as List;
    List<ProductVariant> variants =
    variantsList.map((i) => ProductVariant.fromJson(i)).toList();

    return Product(
      id: json['id'],
      name: json['nom'], // Correspond à 'nom' de votre JSON
      description: json['description'],
      prixOriginal: (json['prixOriginal'] as num).toDouble(),
      imageUrl: json['imageUrl'],
      restaurantId: json['restaurantId'],
      categoryId: json['categoryId'],
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
      variants: variants,
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