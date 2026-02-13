
import 'package:lilia_app/models/produit.dart';

/// Enum des jours de la semaine
enum DayOfWeek {
  LUNDI,
  MARDI,
  MERCREDI,
  JEUDI,
  VENDREDI,
  SAMEDI,
  DIMANCHE;

  String get label {
    switch (this) {
      case DayOfWeek.LUNDI: return 'Lundi';
      case DayOfWeek.MARDI: return 'Mardi';
      case DayOfWeek.MERCREDI: return 'Mercredi';
      case DayOfWeek.JEUDI: return 'Jeudi';
      case DayOfWeek.VENDREDI: return 'Vendredi';
      case DayOfWeek.SAMEDI: return 'Samedi';
      case DayOfWeek.DIMANCHE: return 'Dimanche';
    }
  }

  String get shortLabel {
    switch (this) {
      case DayOfWeek.LUNDI: return 'Lun';
      case DayOfWeek.MARDI: return 'Mar';
      case DayOfWeek.MERCREDI: return 'Mer';
      case DayOfWeek.JEUDI: return 'Jeu';
      case DayOfWeek.VENDREDI: return 'Ven';
      case DayOfWeek.SAMEDI: return 'Sam';
      case DayOfWeek.DIMANCHE: return 'Dim';
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
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      dayOfWeek: DayOfWeek.fromString(json['dayOfWeek'] ?? 'LUNDI'),
      openTime: json['openTime'] ?? '08:00',
      closeTime: json['closeTime'] ?? '22:00',
      isClosed: json['isClosed'] ?? false,
    );
  }
}

/// Modèle pour les spécialités d'un restaurant
class Specialty {
  final String id;
  final String name;

  Specialty({required this.id, required this.name});

  factory Specialty.fromJson(Map<String, dynamic> json) {
    return Specialty(
      id: json['id'],
      name: json['name'],
    );
  }
}

/// Modèle simplifié pour la liste des restaurants (sans les produits)
class RestaurantSummary {
  final String id;
  final String name;
  final String address;
  final String? phoneNumber;
  final String? imageUrl;
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

  RestaurantSummary({
    required this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    this.imageUrl,
    this.description,
    this.averageRating,
    this.totalReviews,
    this.isOpen = true,
    this.specialties = const [],
    this.estimatedDeliveryTimeMin = 15,
    this.estimatedDeliveryTimeMax = 30,
    this.minimumOrderAmount = 0,
    this.fixedDeliveryFee = 500,
  });

  /// Retourne le temps de livraison formaté (ex: "15-30 min")
  String get deliveryTimeFormatted =>
      '$estimatedDeliveryTimeMin-$estimatedDeliveryTimeMax min';

  /// Retourne les spécialités formatées (ex: "Pizza, Burger, Sushi")
  String get specialtiesFormatted =>
      specialties.map((s) => s.name).join(', ');

  factory RestaurantSummary.fromJson(Map<String, dynamic> json) {
    // Parser les spécialités
    List<Specialty> specialties = [];
    if (json['specialties'] != null) {
      specialties = (json['specialties'] as List)
          .map((s) => Specialty.fromJson(s))
          .toList();
    }

    return RestaurantSummary(
      id: json['id'],
      name: json['nom'],
      address: json['adresse'],
      phoneNumber: json['phone'],
      imageUrl: json['imageUrl'],
      description: json['description'],
      averageRating: json['averageRating'] != null
          ? (json['averageRating'] as num).toDouble()
          : null,
      totalReviews: json['totalReviews'] as int?,
      isOpen: json['isOpen'] ?? true,
      specialties: specialties,
      estimatedDeliveryTimeMin: json['estimatedDeliveryTimeMin'] ?? 15,
      estimatedDeliveryTimeMax: json['estimatedDeliveryTimeMax'] ?? 30,
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble() ?? 0,
      fixedDeliveryFee: (json['fixedDeliveryFee'] as num?)?.toDouble() ?? 500,
    );
  }
}

class Restaurant {
  final String id;
  final String name;
  final String address;
  final String? phoneNumber;
  final String? imageUrl;
  final List<Product> products;
  final Map<String, Category> categoriesMap;

  // Nouveaux champs
  final bool isOpen;
  final List<Specialty> specialties;
  final List<OperatingHours> operatingHours;
  final int estimatedDeliveryTimeMin;
  final int estimatedDeliveryTimeMax;
  final double minimumOrderAmount;
  final double fixedDeliveryFee;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    this.imageUrl,
    required this.products,
    required this.categoriesMap,
    this.isOpen = true,
    this.specialties = const [],
    this.operatingHours = const [],
    this.estimatedDeliveryTimeMin = 15,
    this.estimatedDeliveryTimeMax = 30,
    this.minimumOrderAmount = 0,
    this.fixedDeliveryFee = 500,
  });

  /// Retourne le temps de livraison formaté
  String get deliveryTimeFormatted =>
      '$estimatedDeliveryTimeMin-$estimatedDeliveryTimeMax min';

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

    // Parser les spécialités
    List<Specialty> specialties = [];
    if (json['specialties'] != null) {
      specialties = (json['specialties'] as List)
          .map((s) => Specialty.fromJson(s))
          .toList();
    }

    // Parser les horaires d'ouverture
    List<OperatingHours> operatingHours = [];
    if (json['operatingHours'] != null) {
      operatingHours = (json['operatingHours'] as List)
          .map((h) => OperatingHours.fromJson(h))
          .toList();
    }

    return Restaurant(
      id: json['id'],
      name: json['nom'],
      address: json['adresse'],
      phoneNumber: json['phone'],
      imageUrl: json['imageUrl'],
      products: products,
      categoriesMap: categoriesMap,
      isOpen: json['isOpen'] ?? true,
      specialties: specialties,
      operatingHours: operatingHours,
      estimatedDeliveryTimeMin: json['estimatedDeliveryTimeMin'] ?? 15,
      estimatedDeliveryTimeMax: json['estimatedDeliveryTimeMax'] ?? 30,
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble() ?? 0,
      fixedDeliveryFee: (json['fixedDeliveryFee'] as num?)?.toDouble() ?? 500,
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