import 'package:lilia_app/features/settings/data/platform_settings_service.dart';

/// Estimation du montant d'une commande **avant** son envoi au serveur.
///
/// Trois divergences avec le backend existaient dans le calcul inline de
/// `CheckoutPage`, toutes reproduites ici à l'identique de
/// `OrderCheckoutService` :
///
/// 1. **Taux de commission** — le client utilisait `0.08` en dur ; le serveur
///    lit `PlatformSettings.serviceFeePercent`, modifiable par l'admin.
/// 2. **Arrondi de la fidélité** — le serveur convertit en points entiers
///    (`floor(dû / valeurDuPoint)`) ; le client plafonnait à la valeur brute.
///    Sur un montant dû de 703 FCFA, le client affichait 0 à payer quand le
///    serveur en facturait 3.
/// 3. **Frais de livraison de repli** — traité en amont
///    (`delivery_options_page`), qui appliquait 500 FCFA en silence là où le
///    défaut serveur est 1000.
///
/// Extrait dans le domaine pour être testable : c'était la fonction la plus
/// proche de l'argent et la seule non couverte.
class CheckoutEstimate {
  final double subTotal;
  final double deliveryFee;
  final double serviceFee;
  final double promoDiscount;
  final double loyaltyDiscount;
  final int loyaltyPointsUsed;
  final double total;

  const CheckoutEstimate({
    required this.subTotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.promoDiscount,
    required this.loyaltyDiscount,
    required this.loyaltyPointsUsed,
    required this.total,
  });

  /// Reproduit `OrderCheckoutService.createOrderFromCart` étape par étape.
  factory CheckoutEstimate.compute({
    required double subTotal,
    required double deliveryFee,
    required double promoDiscount,
    required int loyaltyPoints,
    required bool useLoyaltyPoints,
    required PlatformSettings settings,
  }) {
    // Le serveur arrondit la commission (`order-calculator.service`).
    final serviceFee = (subTotal * settings.serviceFeeRate).roundToDouble();

    // Montant restant dû une fois la promo appliquée.
    final remaining = (subTotal + deliveryFee + serviceFee - promoDiscount)
        .clamp(0, double.infinity)
        .toDouble();

    var loyaltyPointsUsed = 0;
    var loyaltyDiscount = 0.0;

    // ⚠️ Assiette des points : le **panier alimentaire**, pas le montant dû.
    //
    // Les points s'imputaient sur `subTotal + livraison + frais de service` ;
    // ils finançaient donc la course du livreur et les frais de
    // fonctionnement, deux postes réellement décaissés que le reversement
    // vendeur ne compense pas. Ils ne réduisent plus que la nourriture, une
    // fois la promo passée dessus.
    //
    // Miroir exact de `OrderCheckoutService` : un écart ici afficherait un
    // total que le serveur ne facturerait pas.
    final redeemableBase = (subTotal - promoDiscount)
        .clamp(0, double.infinity)
        .toDouble();

    // Le solde doit atteindre le minimum de rachat, sinon aucun point n'est
    // utilisable — même règle que `settings.loyaltyMinRedemption` côté serveur.
    if (useLoyaltyPoints && loyaltyPoints >= settings.loyaltyMinRedemption) {
      final usablePoints = redeemableBase ~/ settings.loyaltyPointValueXaf;
      loyaltyPointsUsed = loyaltyPoints < usablePoints
          ? loyaltyPoints
          : usablePoints;
      loyaltyDiscount = (loyaltyPointsUsed * settings.loyaltyPointValueXaf)
          .toDouble();
    }

    return CheckoutEstimate(
      subTotal: subTotal,
      deliveryFee: deliveryFee,
      serviceFee: serviceFee,
      promoDiscount: promoDiscount,
      loyaltyDiscount: loyaltyDiscount,
      loyaltyPointsUsed: loyaltyPointsUsed,
      total: (remaining - loyaltyDiscount).clamp(0, double.infinity).toDouble(),
    );
  }
}
