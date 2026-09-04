// ignore_for_file: constant_identifier_names

/// Marketplace multi-vendeurs (LIL-117).
///
/// Aligné sur les enums Prisma backend. RESTAURANT reste le comportement
/// historique ; les autres types ont une UX adaptée côté client. ALCOHOL
/// existe dans l'enum DB mais n'est jamais proposé côté UI (pivot lancement
/// Lilia Food — pas de vente d'alcool, cf. memory `project-lilia-no-alcohol-initial`).
library;

enum VendorType {
  RESTAURANT,
  HOME_COOK,
  BAKERY,
  BEVERAGE_SHOP,
  GROCERY;

  String get label {
    switch (this) {
      case VendorType.RESTAURANT:
        return 'Restaurant';
      case VendorType.HOME_COOK:
        return 'Cuisine maison';
      case VendorType.BAKERY:
        return 'Boulangerie';
      case VendorType.BEVERAGE_SHOP:
        return 'Boissons';
      case VendorType.GROCERY:
        return 'Épicerie';
    }
  }

  String get shortLabel {
    switch (this) {
      case VendorType.RESTAURANT:
        return 'Resto';
      case VendorType.HOME_COOK:
        return 'Maison';
      case VendorType.BAKERY:
        return 'Boulanger';
      case VendorType.BEVERAGE_SHOP:
        return 'Boissons';
      case VendorType.GROCERY:
        return 'Épicerie';
    }
  }

  /// Emoji symbolique pour les badges compactes
  String get emoji {
    switch (this) {
      case VendorType.RESTAURANT:
        return '🍽️';
      case VendorType.HOME_COOK:
        return '🥧';
      case VendorType.BAKERY:
        return '🥐';
      case VendorType.BEVERAGE_SHOP:
        return '🥤';
      case VendorType.GROCERY:
        return '🛒';
    }
  }

  /// Libellé du lieu de retrait dans l'UI checkout — adapte
  /// "Retrait à la boulangerie" / "chez le vendeur" / etc.
  String get pickupLocationLabel {
    switch (this) {
      case VendorType.RESTAURANT:
        return 'au restaurant';
      case VendorType.HOME_COOK:
        return 'chez le vendeur';
      case VendorType.BAKERY:
        return 'à la boulangerie';
      case VendorType.BEVERAGE_SHOP:
        return 'au point de vente';
      case VendorType.GROCERY:
        return 'à la boutique';
    }
  }

  /// Types proposés au filtre marketplace. GROCERY est exclu tant qu'on
  /// n'a pas de vrai catalogue d'épicerie (réservé futur côté backend).
  static const List<VendorType> marketplaceFilter = [
    VendorType.RESTAURANT,
    VendorType.HOME_COOK,
    VendorType.BAKERY,
    VendorType.BEVERAGE_SHOP,
  ];

  static VendorType fromString(String? value) {
    return VendorType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VendorType.RESTAURANT,
    );
  }
}

enum ProductType {
  FOOD,
  BEVERAGE,
  ALCOHOL,
  PASTRY,
  GROCERY;

  String get label {
    switch (this) {
      case ProductType.FOOD:
        return 'Plat';
      case ProductType.BEVERAGE:
        return 'Boisson';
      case ProductType.PASTRY:
        return 'Pâtisserie';
      case ProductType.GROCERY:
        return 'Épicerie';
      case ProductType.ALCOHOL:
        return 'Alcool';
    }
  }

  static ProductType fromString(String? value) {
    return ProductType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProductType.FOOD,
    );
  }
}

enum StockMode {
  DAILY,
  PERMANENT;

  static StockMode fromString(String? value) {
    return StockMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StockMode.DAILY,
    );
  }
}
