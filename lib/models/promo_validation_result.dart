/// Résultat de la validation d'un code promo via POST /promo/validate.
class PromoValidationResult {
  final bool valid;
  final String promoCodeId;
  final String code;
  final DiscountType discountType;
  final double discountAmount;
  final String? description;
  final double newTotal;
  final double newDeliveryFee;

  const PromoValidationResult({
    required this.valid,
    required this.promoCodeId,
    required this.code,
    required this.discountType,
    required this.discountAmount,
    this.description,
    required this.newTotal,
    required this.newDeliveryFee,
  });

  factory PromoValidationResult.fromJson(Map<String, dynamic> json) {
    return PromoValidationResult(
      valid: json['valid'] as bool? ?? false,
      promoCodeId: json['promoCodeId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      discountType: DiscountType.fromString(json['discountType'] as String?),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String?,
      newTotal: (json['newTotal'] as num?)?.toDouble() ?? 0,
      newDeliveryFee: (json['newDeliveryFee'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Label lisible pour l'affichage du type de réduction.
  String get discountLabel {
    switch (discountType) {
      case DiscountType.fixed:
        return '-${discountAmount.toStringAsFixed(0)} FCFA';
      case DiscountType.percent:
        return '-${discountAmount.toStringAsFixed(0)} FCFA';
      case DiscountType.freeDelivery:
        return 'Livraison gratuite';
    }
  }
}

enum DiscountType {
  fixed,
  percent,
  freeDelivery;

  static DiscountType fromString(String? value) {
    switch (value) {
      case 'FIXED':
        return DiscountType.fixed;
      case 'PERCENT':
        return DiscountType.percent;
      case 'FREE_DELIVERY':
        return DiscountType.freeDelivery;
      default:
        return DiscountType.fixed;
    }
  }
}
