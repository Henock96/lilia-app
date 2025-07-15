import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/order.dart';
import 'order_repository.dart';


part 'order_controller.g.dart';

/*@riverpod
Future<List<Order>> userOrders(UserOrdersRef ref) async {
  // Le contrôleur watch le fournisseur du repository, qui maintenant gère le token.
  final repository = ref.watch(orderRepositoryProvider.notifier); // Accédez au Notifier
  return repository.getMyOrders();
}*/

@Riverpod(keepAlive: true)
class UserOrders extends _$UserOrders {

  @override
  Future<List<Order>> build() async {
    // La méthode build charge les données initiales
    return ref.read(orderRepositoryProvider.notifier).getMyOrders();
  }

  // Méthode pour annuler une commande
  Future<void> cancelOrder(String orderId) async {
    // On ne change pas l'état ici pour éviter un rechargement de toute la liste
    // On va juste appeler le repo et rafraîchir la liste après
    try {
      await ref.read(orderRepositoryProvider.notifier).cancelOrder(orderId);
      // Rafraîchir la liste pour refléter le changement de statut
      ref.invalidateSelf();
    } catch (e) {
      // Propage l'erreur pour que l'UI puisse l'afficher
      rethrow;
    }
  }
}