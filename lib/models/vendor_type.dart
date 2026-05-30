// ignore_for_file: constant_identifier_names

/// Types de vendeurs sur la marketplace Lilia (cf. backend `VendorType`).
/// Aligné avec l'enum backend Prisma. RESTAURANT reste le comportement
/// historique ; les autres types ont une UX adaptée côté client.
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
        return 'Fait maison';
      case VendorType.BAKERY:
        return 'Boulangerie';
      case VendorType.BEVERAGE_SHOP:
        return 'Boissons';
      case VendorType.GROCERY:
        return 'Épicerie';
    }
  }

  String get emoji {
    switch (this) {
      case VendorType.RESTAURANT:
        return '🍽️';
      case VendorType.HOME_COOK:
        return '🍲';
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

  static VendorType fromString(String? value) {
    return VendorType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VendorType.RESTAURANT,
    );
  }
}
