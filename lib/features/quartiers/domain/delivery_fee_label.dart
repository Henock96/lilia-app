import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/utils/currency.dart';

/// Ce que les cartes et la fiche vendeur disent du prix de la livraison.
///
/// En mode vendeur, `fixedDeliveryFee` est un vrai prix. En mode plateforme
/// (F3-02) il ne veut plus rien dire : le prix dépend de la distance jusqu'au
/// quartier du client, que la carte ne connaît pas. On annonce alors le
/// plancher de la grille (« dès X »), jamais un prix inventé.
///
/// Barème pas encore chargé (`settings == null`) : comportement d'avant la
/// bascule, le prix du vendeur.
String deliveryFeeLabel(
  double fixedDeliveryFee,
  PlatformSettings? settings, {
  String free = 'Gratuit',
}) {
  if (settings != null && settings.isPlatformDeliveryPricing) {
    final floor = settings.deliveryFeeFromXaf;
    if (floor == null) return 'Selon la distance';
    if (floor == 0) return free;
    return 'Dès ${formatPrice(floor.toDouble())}';
  }
  return fixedDeliveryFee == 0 ? free : formatPrice(fixedDeliveryFee);
}
