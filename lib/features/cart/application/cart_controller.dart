import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';

part 'cart_controller.g.dart';

@riverpod
CartRepository cartRepository(Ref ref) {
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
    Future.microtask(
      () => cartRepository.getCart(),
    ); // Déclenche la récupération initiale
    ref.onDispose(() {
      //cartRepository.clearCart();
    }); // Vide le panier à la déconnexion
    return cartRepository.watchCart(); // Et écoute les changements
  }

  Future<void> addItem({required String variantId, int quantity = 1}) async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      await cartRepo.addToCart(variantId: variantId, quantity: quantity);
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout au panier: $e');
      rethrow;
    }
  }

  Future<void> updateItemQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      await cartRepo.updateItemQuantity(
        cartItemId: cartItemId,
        quantity: quantity,
      );
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de la quantité: $e');
      rethrow;
    }
  }

  Future<void> removeItem({required String cartItemId}) async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      await cartRepo.removeItem(cartItemId: cartItemId);
    } catch (e) {
      debugPrint('Erreur lors de la suppression de l\'article: $e');
      rethrow;
    }
  }

  Future<void> clearCart() async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      cartRepo.clearCart();
    } catch (e) {
      debugPrint('Erreur lors du vidage du panier: $e');
      rethrow;
    }
  }

  Future<void> refresh() async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.getCart();
  }

  /// Recommande une commande précédente
  /// Retourne les détails du reorder (produits ajoutés, indisponibles, etc.)
  Future<Map<String, dynamic>> reorder({required String orderId}) async {
    final cartRepo = ref.read(cartRepositoryProvider);
    try {
      final result = await cartRepo.reorderFromOrder(orderId: orderId);
      return result;
    } catch (e) {
      debugPrint('Erreur lors de la recommande: $e');
      rethrow;
    }
  }
}
