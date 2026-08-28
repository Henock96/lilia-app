import 'package:lilia_app/models/gallery_image.dart';
import 'package:lilia_app/models/produit.dart';

class MenuDuJour {
  final String id;
  final String nom;
  final String? description;
  final String? imageUrl;
  // Galerie multi-images (MenuImage côté backend).
  final List<GalleryImage> images;
  final double prix;
  final String type; // 'COMBO' ou 'PLAT_SPECIAL'
  final String? ingredients; // Composition pour PLAT_SPECIAL
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
    this.images = const [],
    required this.prix,
    this.type = 'COMBO',
    this.ingredients,
    required this.dateDebut,
    required this.dateFin,
    required this.isActive,
    required this.restaurantId,
    required this.restaurant,
    required this.products,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPlatSpecial => type == 'PLAT_SPECIAL';

  /// URLs à afficher dans le carrousel d'en-tête : la galerie si disponible,
  /// sinon l'`imageUrl` legacy en fallback.
  List<String> get galleryUrls {
    if (images.isNotEmpty) return [for (final img in images) img.url];
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return [imageUrl!];
    return const [];
  }

  /// Vignette pour les cartes de liste : cover de la galerie si disponible,
  /// sinon l'`imageUrl` legacy. `null` si aucune image (→ placeholder).
  String? get thumbnailUrl => galleryUrls.isNotEmpty ? galleryUrls.first : null;

  factory MenuDuJour.fromJson(Map<String, dynamic> json) {
    var productsList = json['products'] as List? ?? [];
    List<MenuProduct> products = productsList
        .map((i) => MenuProduct.fromJson(i as Map<String, dynamic>))
        .toList();

    return MenuDuJour(
      id: json['id'] as String,
      nom: json['nom'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      images: GalleryImage.listFrom(json['images']),
      prix: (json['prix'] as num).toDouble(),
      type: json['type'] as String? ?? 'COMBO',
      ingredients: json['ingredients'] as String?,
      dateDebut: DateTime.parse(json['dateDebut'] as String),
      dateFin: DateTime.parse(json['dateFin'] as String),
      isActive: (json['isActive'] as bool?) ?? true,
      restaurantId: json['restaurantId'] as String,
      restaurant: MenuRestaurant.fromJson(
        json['restaurant'] as Map<String, dynamic>,
      ),
      products: products,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
      id: json['id'] as String,
      menuId: json['menuId'] as String,
      productId: json['productId'] as String,
      ordre: (json['ordre'] as int?) ?? 0,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class MenuRestaurant {
  final String id;
  final String nom;
  final String? imageUrl;

  MenuRestaurant({required this.id, required this.nom, this.imageUrl});

  factory MenuRestaurant.fromJson(Map<String, dynamic> json) {
    return MenuRestaurant(
      id: json['id'] as String,
      nom: json['nom'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
