import 'package:lilia_app/models/vendor_type.dart';

/// Modes de service qu'un vendeur propose au client : livraison, retrait sur
/// place, ou les deux.
///
/// **Le serveur décide** : `supportsDelivery` / `supportsPickup` sont relus au
/// checkout, qui refuse un mode non proposé (`DELIVERY_UNAVAILABLE`,
/// `PICKUP_UNAVAILABLE`). Cette classe ne fait qu'éviter de proposer un choix
/// voué au refus — elle n'autorise rien.
///
/// ⚠️ `HOME_COOK` : le retrait reste masqué côté client quand la livraison
/// est proposée (LIL-131 — un vendeur maison n'a pas de point de vente).
/// Cette règle n'existe **que** dans l'app ; le serveur, lui, accepte un
/// retrait chez un `HOME_COOK` qui l'a déclaré. Comportement préservé au
/// Lot 1, l'aligner relève d'une décision distincte. Un `HOME_COOK` qui ne
/// déclare **que** le retrait le garde : le masquer le rendrait
/// incommandable alors que le serveur l'accepte.
class ServiceModes {
  const ServiceModes({required this.delivery, required this.pickup});

  factory ServiceModes.of({
    required bool supportsDelivery,
    required bool supportsPickup,
    required VendorType vendorType,
  }) {
    return ServiceModes(
      delivery: supportsDelivery,
      pickup:
          supportsPickup &&
          !(vendorType == VendorType.HOME_COOK && supportsDelivery),
    );
  }

  final bool delivery;
  final bool pickup;

  /// Aucun mode : le vendeur ne peut servir personne (état que le serveur
  /// refuse d'enregistrer, mais qu'une donnée ancienne peut porter).
  bool get none => !delivery && !pickup;

  bool offers({required bool isDelivery}) => isDelivery ? delivery : pickup;

  /// Mode à retenir : le choix courant s'il est proposé, sinon le seul mode
  /// proposé, `null` s'il n'y en a aucun.
  bool? resolve({required bool isDelivery}) {
    if (offers(isDelivery: isDelivery)) return isDelivery;
    if (delivery) return true;
    if (pickup) return false;
    return null;
  }
}
