import 'package:lilia_app/models/produit.dart';

class MenuDuJour {
  final String id;
  final String nom;
  final String? description;
  final String? imageUrl;
  final double prix;
  final DateTime dateDebut;
  final DateTime dateFin;
  final bool isActive;
  final String restaurantId;
  final MenuRestaurant restaurant;
  final List<MenuProduct> products;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuDuJour({
    required this.id,
    required this.nom,
    this.description,
    this.imageUrl,
    required this.prix,
    required this.dateDebut,
    required this.dateFin,
    required this.isActive,
    required this.restaurantId,
    required this.restaurant,
    required this.products,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuDuJour.fromJson(Map<String, dynamic> json) {
    var productsList = json['products'] as List? ?? [];
    List<MenuProduct> products =
        productsList.map((i) => MenuProduct.fromJson(i)).toList();

    return MenuDuJour(
      id: json['id'],
      nom: json['nom'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      prix: (json['prix'] as num).toDouble(),
      dateDebut: DateTime.parse(json['dateDebut']),
      dateFin: DateTime.parse(json['dateFin']),
      isActive: json['isActive'] ?? true,
      restaurantId: json['restaurantId'],
      restaurant: MenuRestaurant.fromJson(json['restaurant']),
      products: products,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Vérifie si le menu est actuellement valide (dans la période + actif)
  bool get isCurrentlyValid {
    final now = DateTime.now();
    return isActive && now.isAfter(dateDebut) && now.isBefore(dateFin);
  }

  // Vérifie si le menu est expiré
  bool get isExpired {
    return DateTime.now().isAfter(dateFin);
  }
}

class MenuProduct {
  final String id;
  final String menuId;
  final String productId;
  final int ordre;
  final Product product;
  final DateTime createdAt;

  MenuProduct({
    required this.id,
    required this.menuId,
    required this.productId,
    required this.ordre,
    required this.product,
    required this.createdAt,
  });

  factory MenuProduct.fromJson(Map<String, dynamic> json) {
    return MenuProduct(
      id: json['id'],
      menuId: json['menuId'],
      productId: json['productId'],
      ordre: json['ordre'] ?? 0,
      product: Product.fromJson(json['product']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class MenuRestaurant {
  final String id;
  final String nom;
  final String? imageUrl;

  MenuRestaurant({
    required this.id,
    required this.nom,
    this.imageUrl,
  });

  factory MenuRestaurant.fromJson(Map<String, dynamic> json) {
    return MenuRestaurant(
      id: json['id'],
      nom: json['nom'],
      imageUrl: json['imageUrl'],
    );
  }
}
