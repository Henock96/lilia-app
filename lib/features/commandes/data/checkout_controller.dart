// lib/controllers/checkout_controller.dart (NOUVEAU)
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// Pour invalider le panier après commande

part 'checkout_controller.g.dart';

@Riverpod(keepAlive: true)
class CheckoutController extends _$CheckoutController {
  @override
  FutureOr<void> build() {
    // État initial, rien à faire ici pour un Notifier qui gère des actions
  }

  Future<void> placeOrder({
    required String adresseId,
    required String paymentMethod,
    String? newAddressRue,
    String? newAddressVille,
    String? newAddressCountry,
    String? newAddressComplement,
    String? newPhoneNumber,
  }) async {
    state = const AsyncLoading(); // Indique un état de chargement

    try {
      final orderRepository = ref.read(orderRepositoryProvider.notifier);
      await orderRepository.createOrders(
        adresseId: adresseId,
        paymentMethod: paymentMethod,
        newAddressRue: newAddressRue,
        newAddressVille: newAddressVille,
        newAddressCountry: newAddressCountry,
        newAddressComplement: newAddressComplement,
        //newPhoneNumber: newPhoneNumber,
      );

      // Invalider le panier pour qu'il soit rechargé vide après la commande
      ref.invalidate(cartControllerProvider);
      // Invalider les commandes pour que la nouvelle commande apparaisse
      ref.invalidate(userOrdersProvider);

      state = const AsyncData(null); // Succès
    } catch (e, st) {
      state = AsyncError(e, st); // Erreur
      rethrow; // Propage l'erreur pour l'affichage dans l'UI
    }
  }
}