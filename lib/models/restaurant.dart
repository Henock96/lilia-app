
import 'package:lilia_app/models/produit.dart';

class Restaurant {
  final String id;
  final String name;
  final String address;
  final String? phoneNumber; // Peut être nullable si votre backend le permet
  final String? imageUrl; // Peut être nullable
  final List<Product> products;
  final Map<String, Category> categoriesMap; // Pour un accès facile aux catégories par ID

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    this.imageUrl,
    required this.products,
    required this.categoriesMap,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    var productsList = json['products'] as List;
    List<Product> products = productsList.map((i) => Product.fromJson(i)).toList();

    // Construire une map de catégories à partir des produits
    Map<String, Category> categoriesMap = {};
    for (var product in products) {
      if (product.category != null && !categoriesMap.containsKey(product.category!.id)) {
        categoriesMap[product.category!.id] = product.category!;
      }
    }

    return Restaurant(
      id: json['id'],
      name: json['nom'], // Correspond à 'nom' de votre JSON
      address: json['adresse'], // Correspond à 'adresse' de votre JSON
      phoneNumber: json['phone'], // Correspond à 'phone' de votre JSON
      imageUrl: json['imageUrl'],
      products: products,
      categoriesMap: categoriesMap,
    );
  }
}

class Category {
  final String id;
  final String name;

  Category({
    required this.id,
    required this.name,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['nom'], // Correspond à 'nom' de votre JSON
    );
  }
}