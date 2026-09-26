/// Devis du panier renvoyé par `POST /orders/quote` (F3-11).
///
/// C'est **le calcul du checkout**, exécuté par le serveur sans rien écrire :
/// offre boutique, code promo, points de fidélité, frais de service et de
/// livraison compris. Le récapitulatif l'affiche tel quel au lieu de
/// recalculer un total : une offre appliquée sans code n'existe que côté
/// serveur, et chaque recalcul local a déjà divergé du montant encaissé.
class CheckoutQuote {
  const CheckoutQuote({
    required this.subTotal,
    required this.deliveryFee,
    required this.deliveryFeeBeforePromo,
    required this.serviceFee,
    required this.vendorOffer,
    required this.promoDiscount,
    required this.loyaltyPointsUsed,
    required this.loyaltyDiscount,
    required this.total,
  });

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    double n(Object? v) => v is num ? v.toDouble() : 0;
    final promo = json['promo'] is Map<String, dynamic>
        ? json['promo'] as Map<String, dynamic>
        : null;
    final loyalty = json['loyalty'] is Map<String, dynamic>
        ? json['loyalty'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return CheckoutQuote(
      subTotal: n(json['subTotal']),
      deliveryFee: n(json['deliveryFee']),
      deliveryFeeBeforePromo: n(json['deliveryFeeBeforePromo']),
      serviceFee: n(json['serviceFee']),
      vendorOffer: QuotedVendorOffer.tryParse(json['vendorOffer']),
      promoDiscount: n(promo?['discountXaf']),
      loyaltyPointsUsed: (loyalty['pointsUsed'] as num?)?.toInt() ?? 0,
      loyaltyDiscount: n(loyalty['discountXaf']),
      total: n(json['total']),
    );
  }

  final double subTotal;

  /// Après un éventuel code « livraison offerte ».
  final double deliveryFee;
  final double deliveryFeeBeforePromo;
  final double serviceFee;

  /// Offre boutique appliquée à ce panier, `null` sinon.
  final QuotedVendorOffer? vendorOffer;
  final double promoDiscount;
  final int loyaltyPointsUsed;
  final double loyaltyDiscount;
  final double total;
}

/// L'offre boutique telle que le serveur l'applique à CE panier.
class QuotedVendorOffer {
  const QuotedVendorOffer({
    required this.id,
    required this.label,
    required this.discount,
  });

  static QuotedVendorOffer? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final discount = json['discountXaf'];
    if (id is! String || discount is! num) return null;
    return QuotedVendorOffer(
      id: id,
      label: json['label'] as String? ?? 'Offre du vendeur',
      discount: discount.toDouble(),
    );
  }

  /// À renvoyer au checkout (`vendorOfferId`) : si le serveur n'applique plus
  /// la même offre au moment de payer, il refuse en 409 au lieu d'encaisser
  /// un autre montant que celui affiché.
  final String id;
  final String label;
  final double discount;
}
