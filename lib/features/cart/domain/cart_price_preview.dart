import 'package:lilia_app/features/commandes/domain/checkout_estimate.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';

/// Ce que le panier peut dire du prix **avant** le tunnel (P3-11).
///
/// Le panier affichait « 6 500 FCFA » sans libellé ; le checkout y ajoutait
/// ensuite les frais de service (15 % en production) et la livraison. Le client
/// découvrait l'écart à la dernière étape.
///
/// Ce que l'on sait ici, et seulement cela :
///
/// - le **sous-total** des articles (prix unitaires serveur) ;
/// - les **frais de service**, au taux lu sur `/platform-settings` et arrondis
///   par la même fonction que le checkout ([CheckoutEstimate.compute], miroir
///   de `OrderCalculatorService`). Barème injoignable ⇒ `null`, jamais un taux
///   de repli : « pas de réponse, pas de montant » ;
/// - la **livraison** n'est pas connue : elle dépend du mode (retrait gratuit)
///   et de l'adresse. On l'annonce, on ne l'invente pas.
///
/// Offres boutique, codes promo et points s'appliquent à l'étape suivante ; le
/// montant final est celui du devis serveur (`POST /orders/quote`) puis de la
/// commande créée.
class CartPricePreview {
  const CartPricePreview._({
    required this.subTotal,
    required this.serviceFee,
    required this.serviceFeePercent,
  });

  factory CartPricePreview.compute({
    required double subTotal,
    required PlatformSettings? settings,
    /// D-4 — taux de la boutique annoncé par le panier ; `null` : taux général.
    double? serviceFeePercent,
  }) {
    if (settings == null) {
      return CartPricePreview._(
        subTotal: subTotal,
        serviceFee: null,
        serviceFeePercent: null,
      );
    }
    final estimate = CheckoutEstimate.compute(
      subTotal: subTotal,
      deliveryFee: 0,
      promoDiscount: 0,
      loyaltyPoints: 0,
      useLoyaltyPoints: false,
      settings: settings,
      serviceFeePercent: serviceFeePercent,
    );
    return CartPricePreview._(
      subTotal: subTotal,
      serviceFee: estimate.serviceFee,
      serviceFeePercent: serviceFeePercent ?? settings.serviceFeePercent,
    );
  }

  final double subTotal;

  /// `null` : barème indisponible, le montant n'est pas affiché.
  final double? serviceFee;
  final double? serviceFeePercent;

  /// Sous-total + frais de service, **hors livraison et hors remises**.
  /// `null` quand les frais de service ne sont pas connus.
  double? get estimatedTotalBeforeDelivery =>
      serviceFee == null ? null : subTotal + serviceFee!;

  /// « 15 % », « 7,5 % ».
  String? get serviceFeePercentLabel {
    final p = serviceFeePercent;
    if (p == null) return null;
    final txt = p == p.roundToDouble()
        ? p.toStringAsFixed(0)
        : p.toString().replaceAll('.', ',');
    return '$txt %';
  }
}
