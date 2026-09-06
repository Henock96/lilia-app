import 'package:lilia_app/models/gallery_image.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double prixOriginal;
  final String? imageUrl;
  // Galerie multi-images (ProductImage côté backend). Vide si l'API ne la
  // renvoie pas encore ou si le produit n'a que l'imageUrl legacy.
  final List<GalleryImage> images;
  final String restaurantId;
  // categoryId est nullable côté Prisma (String?) — vrai pour les nouveaux
  // produits HOME_COOK/BAKERY créés sans catégorie via admin web (LIL-117).
  final String? categoryId;
  final Category? category;
  final List<ProductVariant> variants;
  final int? stockRestant;
  /// Décision du vendeur : « ce produit est-il proposé à la vente ? »
  ///
  /// ⚠️ À ne pas confondre avec le stock. « Retiré de la vente » et « épuisé »
  /// sont deux notions distinctes que le backend a séparées en août 2026
  /// (fix M2) — la première est un choix, la seconde une conséquence. Ce champ
  /// était **ignoré** par cette classe, recouvert par un getter `isAvailable`
  /// dérivé du seul stock (fix S-3).
  ///
  /// `true` par défaut : les réponses antérieures au champ ne le portent pas,
  /// et un produit servi sans lui est en vente — sinon il n'aurait pas été
  /// servi.
  final bool isAvailable;
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
    this.images = const [],
    required this.restaurantId,
    this.categoryId,
    this.category,
    required this.variants,
    this.stockRestant,
    this.isAvailable = true,
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

  /// Reste-t-il des unités ? `null` = illimité, `0` = épuisé.
  ///
  /// Ce getter s'appelait `isAvailable` et **masquait le champ du serveur** du
  /// même nom : la disponibilité déclarée par le vendeur n'était jamais lue.
  /// Sans conséquence visible sur cette app — `GET /products` filtre déjà
  /// `isAvailable: true`, donc le client ne voit jamais un produit retiré —
  /// mais c'était un piège : le jour où une route servirait le contraire,
  /// l'écran aurait affiché « disponible » sur un produit retiré de la vente.
  bool get isInStock => stockRestant == null || stockRestant! > 0;

  /// Commandable **maintenant** : en vente ET en stock.
  ///
  /// C'est la question que posent les écrans. La poser en un seul endroit
  /// évite que chacun en recompose sa propre version — et en oublie la moitié.
  bool get isOrderable => isAvailable && isInStock;

  /// URLs à afficher dans le carrousel : la galerie si disponible, sinon
  /// l'`imageUrl` legacy en fallback. Vide si aucune image.
  List<String> get galleryUrls {
    if (images.isNotEmpty) return [for (final img in images) img.url];
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return [imageUrl!];
    return const [];
  }

  /// Vignette pour les cartes de liste : cover de la galerie si disponible,
  /// sinon l'`imageUrl` legacy. `null` si aucune image (→ placeholder).
  String? get thumbnailUrl => galleryUrls.isNotEmpty ? galleryUrls.first : null;

  /// Vrai si le produit a une fenêtre horaire et que l'heure actuelle est
  /// dans cette fenêtre. Si pas de fenêtre, toujours vrai (pas de contrainte).
  bool get isWithinAvailabilityWindow {
    if (availableFrom == null || availableUntil == null) return true;
    final now = DateTime.now();
    final current =
        '${now.hour.toString().padLeft(2, '0')}:'
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
    // variants peut être absent ou null pour certains produits — fallback []
    final variantsList = (json['variants'] as List?) ?? const [];
    final variants = variantsList
        .map((i) => ProductVariant.fromJson(i as Map<String, dynamic>))
        .toList();

    return Product(
      id: json['id'] as String,
      name: json['nom'] as String,
      description: (json['description'] as String?) ?? '',
      prixOriginal: (json['prixOriginal'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      images: GalleryImage.listFrom(json['images']),
      restaurantId: json['restaurantId'] as String,
      categoryId: json['categoryId'] as String?,
      category: json['category'] != null
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      variants: variants,
      stockRestant: json['stockRestant'] as int?,
      isAvailable: (json['isAvailable'] as bool?) ?? true,
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
      madeToOrder: (json['madeToOrder'] as bool?) ?? false,
      availableFrom: json['availableFrom'] as String?,
      availableUntil: json['availableUntil'] as String?,
    );
  }
}

class ProductVariant {
  final String id;
  // label est nullable côté Prisma — fallback "Standard" pour l'affichage.
  final String? label;
  final double prix;

  ProductVariant({required this.id, this.label, required this.prix});

  /// Label affichable — jamais null, fallback "Standard".
  String get displayLabel => label ?? 'Standard';

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      label: json['label'] as String?,
      prix: (json['prix'] as num).toDouble(),
    );
  }
}
