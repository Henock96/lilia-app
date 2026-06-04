import 'package:lilia_app/services/analytics_service.dart';
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
    // Copie défensive : ne jamais muter la liste détenue par l'AsyncData
    // courant (sinon on corrompt l'état précédent / les listeners) — C11.
    final currentState = [...(state.value ?? <Order>[])];
    final index = currentState.indexWhere((o) => o.id == order.id);

    if (index != -1) {
      // La commande existe, on la met à jour.
      currentState[index] = order;
    } else {
      // C'est une nouvelle commande, on l'ajoute.
      currentState.insert(0, order);
    }

    // On met à jour l'état avec la nouvelle liste, ce qui rafraîchira l'UI.
    state = AsyncData(currentState);
  }

  // Méthode pour supprimer une commande annulée (backend + local).
  Future<void> removeOrder(String orderId) async {
    final orderRepository = ref.read(orderRepositoryProvider.notifier);
    await orderRepository.deleteOrder(orderId);
    // Copie défensive avant mutation (cf. updateOrAddOrder) — C11.
    final currentState = [...(state.value ?? <Order>[])];
    currentState.removeWhere((o) => o.id == orderId);
    state = AsyncData(currentState);
  }

  // Méthode pour annuler une commande.
  Future<void> cancelOrder(String orderId) async {
    final orderRepository = ref.read(orderRepositoryProvider.notifier);
    await orderRepository.cancelOrder(orderId);
    AnalyticsService.logOrderCancelled(orderId: orderId);

    // Reflète immédiatement l'annulation dans l'état local : sans ça, l'UI ne
    // se rebuild qu'au prochain refresh manuel. On passe le statut à ANNULER
    // (copie défensive) → la commande quitte l'onglet « en cours » pour
    // « annulées ». Le backend a déjà confirmé la transition EN_ATTENTE/PAYER →
    // ANNULER (sinon l'await aurait throw).
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final o in current)
          o.id == orderId ? o.copyWith(status: OrderStatus.annuler) : o,
      ]);
    }
  }
}
