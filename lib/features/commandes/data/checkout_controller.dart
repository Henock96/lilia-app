import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/models/checkout.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkout_controller.g.dart';

@Riverpod(keepAlive: true)
class CheckoutController extends _$CheckoutController {
  @override
  FutureOr<void> build() {}

  /// Passe la commande.
  ///
  /// ⚠️ Aucune coordonnée n'est envoyée ici, et c'est **délibéré**. Ce
  /// contrôleur transmettait `locationService.lastPosition` — le GPS du
  /// téléphone — dans `deliveryLatitude` / `deliveryLongitude`. Le serveur les
  /// recopiait sur la commande : un client commandant depuis son bureau pour
  /// une livraison à domicile envoyait le livreur au bureau.
  ///
  /// La destination se déduit désormais de [adresseId], résolue côté serveur
  /// (`DeliveryDestinationService`). Ne pas rétablir l'envoi de coordonnées
  /// ici : elles seraient ignorées, et la tentation de s'y fier reviendrait.
  Future<Checkout> placeOrder({
    String? adresseId,
    required String paymentMethod,
    required bool isDelivery,
    String? note,
    String? contactPhone,
    String? promoCode,
    bool useLoyaltyPoints = false,
    String? idempotencyKey,
    DateTime? scheduledFor,
  }) async {
    state = const AsyncLoading();

    try {
      final orderRepository = ref.read(orderRepositoryProvider.notifier);
      final order = await orderRepository.createOrders(
        adresseId: adresseId,
        paymentMethod: paymentMethod,
        isDelivery: isDelivery,
        note: note,
        contactPhone: contactPhone,
        promoCode: promoCode,
        useLoyaltyPoints: useLoyaltyPoints,
        idempotencyKey: idempotencyKey,
        scheduledFor: scheduledFor,
      );

      ref.invalidate(cartControllerProvider);
      ref.invalidate(userOrdersProvider);
      ref.invalidate(userProfileProvider);
      // Le solde ET son historique bougent au checkout : n'invalider que le
      // profil laissait la carte fidélité afficher un solde à jour au-dessus
      // d'un historique périmé.
      ref.invalidate(loyaltyTransactionsProvider);
      ref.invalidate(referralStatsProvider);

      state = const AsyncData(null);
      return order;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
