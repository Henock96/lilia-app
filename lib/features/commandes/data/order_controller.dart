import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/models/order.dart';
import 'order_repository.dart';

part 'order_controller.g.dart';

// Utilisation d'un AsyncNotifier pour une gestion d'état asynchrone moderne.
@riverpod
class UserOrders extends _$UserOrders {
  
  // La méthode build charge l'état initial.
  @override
  Future<List<Order>> build() async {
    // On lit le repository et on appelle la méthode pour obtenir les commandes.
    final orderRepository = ref.watch(orderRepositoryProvider.notifier);
    return orderRepository.getMyOrders();
  }

  // Méthode pour mettre à jour une commande dans l'état local ou l'ajouter.
  void updateOrAddOrder(Order order) {
    // On récupère l'état actuel.
    final currentState = state.valueOrNull ?? [];
    final index = currentState.indexWhere((o) => o.id == order.id);

    if (index != -1) {
      // La commande existe, on la met à jour.
      currentState[index] = order;
    } else {
      // C'est une nouvelle commande, on l'ajoute.
      currentState.insert(0, order);
    }

    // On met à jour l'état avec la nouvelle liste, ce qui rafraîchira l'UI.
    state = AsyncData([...currentState]);
  }

  // Méthode pour annuler une commande.
  Future<void> cancelOrder(String orderId) async {
    final orderRepository = ref.read(orderRepositoryProvider.notifier);
    try {
      await orderRepository.cancelOrder(orderId);
      // La mise à jour de l'état se fera via l'événement SSE.
      // Pour une réactivité perçue plus rapide, on pourrait aussi mettre à jour l'état local ici.
    } catch (e) {
      // Propager l'erreur pour que l'UI puisse l'afficher.
      rethrow;
    }
  }
}
