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
/// - le **taux** des frais de service, tel que le serveur l'annonce (taux de la
///   boutique, sinon taux général). Barème injoignable ⇒ `null`, jamais un taux
///   de repli : « pas de réponse, pas de montant » ;
/// - la **livraison** n'est pas connue : elle dépend du mode (retrait gratuit)
///   et de l'adresse. On l'annonce, on ne l'invente pas.
///
/// Durcissement lot 5 (F-40) : aucun montant de frais n'est plus calculé ici.
/// Le premier montant affiché est celui du devis serveur (`POST /orders/quote`),
/// aux étapes suivantes.
class CartPricePreview {
  const CartPricePreview._({
    required this.subTotal,
    required this.serviceFeePercent,
  });

  factory CartPricePreview.compute({
    required double subTotal,
    required PlatformSettings? settings,
    /// D-4 — taux de la boutique annoncé par le panier ; `null` : taux général.
    double? serviceFeePercent,
  }) {
    return CartPricePreview._(
      subTotal: subTotal,
      serviceFeePercent: settings == null
          ? null
          : serviceFeePercent ?? settings.serviceFeePercent,
    );
  }

  final double subTotal;

  /// `null` : barème indisponible, le taux n'est pas affiché.
  final double? serviceFeePercent;

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
