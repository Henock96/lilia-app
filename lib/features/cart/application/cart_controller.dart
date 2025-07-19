import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';

part 'cart_controller.g.dart';

@riverpod
CartRepository cartRepository(CartRepositoryRef ref) {
  final repository = CartRepository();
  ref.onDispose(repository.dispose);
  return repository;
}

@riverpod
class CartController extends _$CartController {
  @override
  Stream<Cart?> build() {
    //final authState = ref.watch(authRepositoryProvider);
    final cartRepository = ref.watch(cartRepositoryProvider);

    // La logiqué est maintenant déclarative et réagit à l'état d'authentification
    // Utilisateur connecté
    cartRepository.getCart(); // Déclenche la récupération initiale
    return cartRepository.watchCart(); // Et écoute les changements
    }

  Future<void> addItem({required String variantId, int quantity = 1}) async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      await cartRepo.addToCart(variantId: variantId, quantity: quantity);
    } catch (e) {
      print('Erreur lors de l\'ajout au panier: $e');
      rethrow;
    }
  }

  Future<void> updateItemQuantity(
      {required String cartItemId, required int quantity}) async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      await cartRepo.updateItemQuantity(
          cartItemId: cartItemId, quantity: quantity);
    } catch (e) {
      print('Erreur lors de la mise à jour de la quantité: $e');
      rethrow;
    }
  }

  Future<void> removeItem({required String cartItemId}) async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      await cartRepo.removeItem(cartItemId: cartItemId);
    } catch (e) {
      print('Erreur lors de la suppression de l\'article: $e');
      rethrow;
    }
  }
}
