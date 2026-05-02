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

  Future<Checkout> placeOrder({
    String? adresseId,
    required String paymentMethod,
    required bool isDelivery,
    String? note,
    String? contactPhone,
    String? promoCode,
    bool useLoyaltyPoints = false,
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
      );

      ref.invalidate(cartControllerProvider);
      ref.invalidate(userOrdersProvider);
      ref.invalidate(userProfileProvider);

      state = const AsyncData(null);
      return order;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
