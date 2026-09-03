import 'package:lilia_app/models/gallery_image.dart';
import 'package:lilia_app/models/menu.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/vendor_type.dart';

/// Enum des jours de la semaine.
///
/// Les valeurs sont en majuscules parce qu'elles sont sérialisées telles quelles
/// vers l'enum Prisma `DayOfWeek` du backend (`e.name == value` plus bas) :
/// les renommer casserait le parsing des horaires d'ouverture.
enum DayOfWeek {
  // ignore_for_file: constant_identifier_names
  LUNDI,
  MARDI,
  MERCREDI,
  JEUDI,
  VENDREDI,
  SAMEDI,
  DIMANCHE;

  String get label {
    switch (this) {
      case DayOfWeek.LUNDI:
        return 'Lundi';
      case DayOfWeek.MARDI:
        return 'Mardi';
      case DayOfWeek.MERCREDI:
        return 'Mercredi';
      case DayOfWeek.JEUDI:
        return 'Jeudi';
      case DayOfWeek.VENDREDI:
        return 'Vendredi';
      case DayOfWeek.SAMEDI:
        return 'Samedi';
      case DayOfWeek.DIMANCHE:
        return 'Dimanche';
    }
  }

  String get shortLabel {
    switch (this) {
      case DayOfWeek.LUNDI:
        return 'Lun';
      case DayOfWeek.MARDI:
        return 'Mar';
      case DayOfWeek.MERCREDI:
        return 'Mer';
      case DayOfWeek.JEUDI:
        return 'Jeu';
      case DayOfWeek.VENDREDI:
        return 'Ven';
      case DayOfWeek.SAMEDI:
        return 'Sam';
      case DayOfWeek.DIMANCHE:
        return 'Dim';
    }
  }

  static DayOfWeek fromString(String value) {
    return DayOfWeek.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DayOfWeek.LUNDI,
    );
  }

  /// Retourne le DayOfWeek correspondant au jour actuel
  static DayOfWeek get today {
    const mapping = {
      1: DayOfWeek.LUNDI,
      2: DayOfWeek.MARDI,
      3: DayOfWeek.MERCREDI,
      4: DayOfWeek.JEUDI,
      5: DayOfWeek.VENDREDI,
      6: DayOfWeek.SAMEDI,
      7: DayOfWeek.DIMANCHE,
    };
    return mapping[DateTime.now().weekday]!;
  }
}

/// Modèle pour les horaires d'ouverture
class OperatingHours {
  final String id;
  final String restaurantId;
  final DayOfWeek dayOfWeek;
  final String openTime;
  final String closeTime;
  final bool isClosed;

  OperatingHours({
    required this.id,
    required this.restaurantId,
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    this.isClosed = false,
  });

  factory OperatingHours.fromJson(Map<String, dynamic> json) {
    return OperatingHours(
      id: (json['id'] as String?) ?? '',
      restaurantId: (json['restaurantId'] as String?) ?? '',
      dayOfWeek: DayOfWeek.fromString(
        (json['dayOfWeek'] as String?) ?? 'LUNDI',
      ),
      openTime: (json['openTime'] as String?) ?? '08:00',
      closeTime: (json['closeTime'] as String?) ?? '22:00',
      isClosed: (json['isClosed'] as bool?) ?? false,
    );
  }
}

/// Modèle pour les spécialités d'un restaurant
class Specialty {
  final String id;
  final String name;

  Specialty({required this.id, required this.name});

  factory Specialty.fromJson(Map<String, dynamic> json) {
    return Specialty(id: json['id'] as String, name: json['name'] as String);
  }
}

/// Profil enrichi d'un vendeur (LIL-112) — story, certifications,
/// specialties, productionNote. Rempli pour les HOME_COOK/BAKERY surtout ;
/// les RESTAURANTs classiques peuvent l'avoir vide.
class VendorProfile {
  final String? story;
  final List<String> certifications;
  final List<String> specialties;
  final String? productionNote;

  VendorProfile({
    this.story,
    this.certifications = const [],
    this.specialties = const [],
    this.productionNote,
  });

  bool get isEmpty =>
      (story == null || story!.isEmpty) &&
      certifications.isEmpty &&
      specialties.isEmpty &&
      (productionNote == null || productionNote!.isEmpty);

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    return VendorProfile(
      story: json['story'] as String?,
      certifications:
          (json['certifications'] as List?)?.map((e) => e as String).toList() ??
          const [],
      specialties:
          (json['specialties'] as List?)?.map((e) => e as String).toList() ??
          const [],
      productionNote: json['productionNote'] as String?,
    );
  }
}

/// Modèle simplifié pour la liste des restaurants (sans les produits)
/// Frais de livraison de repli, aligné sur le défaut Prisma
/// (`Restaurant.fixedDeliveryFee @default(1000)`).
///
/// Le client utilisait 500 FCFA en dur : quand le calcul de zone échouait, il
/// affichait 500 FCFA de moins que ce que le serveur allait facturer, sans le
/// moindre signal.
const double kDefaultDeliveryFee = 1000;

class RestaurantSummary {
  final String id;
  final String name;
  final String address;
  final String? phoneNumber;
  final String? imageUrl;
  // Galerie photos du vendeur (VendorPhoto côté backend).
  final List<GalleryImage> photos;
  final String? description;
  final double? averageRating;
  final int? totalReviews;

  // Nouveaux champs
  final bool isOpen;
  final List<Specialty> specialties;
  final int estimatedDeliveryTimeMin;
  final int estimatedDeliveryTimeMax;
  final double minimumOrderAmount;
  final double fixedDeliveryFee;

  // Multi-vendeurs (LIL-117)
  final VendorType vendorType;
  final bool acceptsPreorders;
  final int? preorderLeadHours;

  RestaurantSummary({
    required this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    this.imageUrl,
    this.photos = const [],
    this.description,
    this.averageRating,
    this.totalReviews,
    this.isOpen = true,
    this.specialties = const [],
    this.estimatedDeliveryTimeMin = 15,
    this.estimatedDeliveryTimeMax = 30,
    this.minimumOrderAmount = 0,
    this.fixedDeliveryFee = kDefaultDeliveryFee,
    this.vendorType = VendorType.RESTAURANT,
    this.acceptsPreorders = false,
    this.preorderLeadHours,
  });

  /// Retourne le temps de livraison formaté (ex: "15-30 min")
  String get deliveryTimeFormatted =>
      '$estimatedDeliveryTimeMin-$estimatedDeliveryTimeMax min';

  /// Retourne les spécialités formatées (ex: "Pizza, Burger, Sushi")
  String get specialtiesFormatted => specialties.map((s) => s.name).join(', ');

  /// Vignette pour les cartes de liste : cover de la galerie photos si
  /// disponible, sinon l'`imageUrl` legacy. `null` si aucune image.
  String? get thumbnailUrl {
    if (photos.isNotEmpty) return photos.first.url;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return imageUrl;
    return null;
  }

  factory RestaurantSummary.fromJson(Map<String, dynamic> json) {
    // Parser les spécialités
    List<Specialty> specialties = [];
    if (json['specialties'] != null) {
      specialties = (json['specialties'] as List)
          .map((s) => Specialty.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return RestaurantSummary(
      id: json['id'] as String,
      name: json['nom'] as String,
      address: json['adresse'] as String,
      phoneNumber: json['phone'] as String?,
      imageUrl: json['imageUrl'] as String?,
      photos: GalleryImage.listFrom(json['photos']),
      description: json['description'] as String?,
      averageRating: json['averageRating'] != null
          ? (json['averageRating'] as num).toDouble()
          : null,
      totalReviews: json['totalReviews'] as int?,
      isOpen: (json['isOpen'] as bool?) ?? true,
      specialties: specialties,
      estimatedDeliveryTimeMin:
          (json['estimatedDeliveryTimeMin'] as int?) ?? 15,
      estimatedDeliveryTimeMax:
          (json['estimatedDeliveryTimeMax'] as int?) ?? 30,
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble() ?? 0,
      fixedDeliveryFee:
          (json['fixedDeliveryFee'] as num?)?.toDouble() ?? kDefaultDeliveryFee,
      vendorType: VendorType.fromString(json['vendorType'] as String?),
      acceptsPreorders: (json['acceptsPreorders'] as bool?) ?? false,
      preorderLeadHours: json['preorderLeadHours'] as int?,
    );
  }
}

class Restaurant {
  final String id;
  final String name;
  final String address;
  final String? phoneNumber;
  final String? imageUrl;
  // Galerie photos du vendeur (VendorPhoto côté backend).
  final List<GalleryImage> photos;
  final List<Product> products;
  final Map<String, Category> categoriesMap;

  /// Sections de la carte **déclarées par le vendeur**, déjà triées par
  /// `displayOrder` côté serveur et filtrées sur `isActive`.
  ///
  /// Distinct de `categoriesMap`, qui est *dérivé des produits* : cette liste-ci
  /// porte l'ordre voulu par le commerçant. Sans elle, l'écran de détail triait
  /// les sections par ordre alphabétique — « Accompagnements » passait avant
  /// « Les Grillades », qui est pourtant le cœur de l'offre.
  ///
  /// Vide si le backend ne l'a pas renvoyée : l'écran retombe alors sur
  /// l'ancien comportement plutôt que d'afficher une carte sans sections.
  final List<Category> categories;

  // Nouveaux champs
  final bool isOpen;
  final List<Specialty> specialties;
  final List<OperatingHours> operatingHours;
  final int estimatedDeliveryTimeMin;
  final int estimatedDeliveryTimeMax;
  final double minimumOrderAmount;
  final double fixedDeliveryFee;
  final double? averageRating;
  final int? totalReviews;

  // Multi-vendeurs (LIL-117) — drive l'UI (badge, options retrait, profil enrichi, etc.)
  final VendorType vendorType;
  final bool acceptsPreorders;
  final int? preorderLeadHours;
  final VendorProfile? vendorProfile;

  // Menus du jour actifs embarqués dans `GET /vendors/:id` (clé `menuDuJour`).
  // Évite une 2e requête `/menus/active` sur l'écran de détail vendeur.
  final List<MenuDuJour> menus;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    this.imageUrl,
    this.photos = const [],
    required this.products,
    required this.categoriesMap,
    this.categories = const [],
    this.isOpen = true,
    this.specialties = const [],
    this.operatingHours = const [],
    this.estimatedDeliveryTimeMin = 15,
    this.estimatedDeliveryTimeMax = 30,
    this.minimumOrderAmount = 0,
    this.fixedDeliveryFee = kDefaultDeliveryFee,
    this.averageRating,
    this.totalReviews,
    this.vendorType = VendorType.RESTAURANT,
    this.acceptsPreorders = false,
    this.preorderLeadHours,
    this.vendorProfile,
    this.menus = const [],
  });

  /// Retourne le temps de livraison formaté
  String get deliveryTimeFormatted =>
      '$estimatedDeliveryTimeMin-$estimatedDeliveryTimeMax min';

  /// URLs à afficher dans le carrousel d'en-tête : la galerie photos si
  /// disponible, sinon l'`imageUrl` legacy en fallback.
  List<String> get galleryUrls {
    if (photos.isNotEmpty) return [for (final p in photos) p.url];
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return [imageUrl!];
    return const [];
  }

  /// Vignette pour les cartes de liste : cover de la galerie si disponible,
  /// sinon l'`imageUrl` legacy. `null` si aucune image (→ placeholder).
  String? get thumbnailUrl => galleryUrls.isNotEmpty ? galleryUrls.first : null;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    var productsList = (json['products'] as List?) ?? [];
    List<Product> products = productsList
        .map((i) => Product.fromJson(i as Map<String, dynamic>))
        .toList();

    // Construire une map de catégories à partir des produits
    Map<String, Category> categoriesMap = {};
    for (var product in products) {
      if (product.category != null &&
          !categoriesMap.containsKey(product.category!.id)) {
        categoriesMap[product.category!.id] = product.category!;
      }
    }

    // Sections déclarées par le vendeur (ordre serveur préservé).
    final declaredCategories = (json['categories'] as List?)
            ?.map((c) => Category.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const <Category>[];

    // Parser les spécialités
    List<Specialty> specialties = [];
    if (json['specialties'] != null) {
      specialties = (json['specialties'] as List)
          .map((s) => Specialty.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    // Parser les horaires d'ouverture
    List<OperatingHours> operatingHours = [];
    if (json['operatingHours'] != null) {
      operatingHours = (json['operatingHours'] as List)
          .map((h) => OperatingHours.fromJson(h as Map<String, dynamic>))
          .toList();
    }

    // Menus du jour actifs embarqués (clé relation Prisma `menuDuJour`).
    List<MenuDuJour> menus = [];
    if (json['menuDuJour'] != null) {
      menus = (json['menuDuJour'] as List)
          .map((m) => MenuDuJour.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return Restaurant(
      id: json['id'] as String,
      name: json['nom'] as String,
      address: json['adresse'] as String,
      phoneNumber: json['phone'] as String?,
      imageUrl: json['imageUrl'] as String?,
      photos: GalleryImage.listFrom(json['photos']),
      products: products,
      categoriesMap: categoriesMap,
      categories: declaredCategories,
      isOpen: (json['isOpen'] as bool?) ?? true,
      specialties: specialties,
      operatingHours: operatingHours,
      estimatedDeliveryTimeMin:
          (json['estimatedDeliveryTimeMin'] as int?) ?? 15,
      estimatedDeliveryTimeMax:
          (json['estimatedDeliveryTimeMax'] as int?) ?? 30,
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble() ?? 0,
      fixedDeliveryFee:
          (json['fixedDeliveryFee'] as num?)?.toDouble() ?? kDefaultDeliveryFee,
      averageRating: json['averageRating'] != null
          ? (json['averageRating'] as num).toDouble()
          : null,
      totalReviews: json['totalReviews'] as int?,
      vendorType: VendorType.fromString(json['vendorType'] as String?),
      acceptsPreorders: (json['acceptsPreorders'] as bool?) ?? false,
      preorderLeadHours: json['preorderLeadHours'] as int?,
      vendorProfile: json['vendorProfile'] != null
          ? VendorProfile.fromJson(
              json['vendorProfile'] as Map<String, dynamic>,
            )
          : null,
      menus: menus,
    );
  }
}

/// Section de la carte d'un vendeur.
///
/// Elle appartient à un commerce et à un seul : deux vendeurs peuvent avoir
/// chacun leur « Boissons », et ce sont deux sections distinctes.
class Category {
  final String id;
  final String name;

  /// Ordre voulu par le vendeur. Le serveur trie déjà, ce champ sert de repli
  /// si une liste est recomposée côté client.
  final int displayOrder;

  /// Une section inactive n'est jamais servie au client — le champ existe pour
  /// que l'app ne se fie pas *uniquement* au filtrage serveur.
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['nom'] as String, // Correspond à 'nom' de votre JSON
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
