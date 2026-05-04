
import 'package:flutter/foundation.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/draft_order.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'draft_orders_provider.g.dart';

const _storageKey = 'draft_orders';

@Riverpod(keepAlive: true)
class DraftOrdersNotifier extends _$DraftOrdersNotifier {
  @override
  Future<List<DraftOrder>> build() async {
    return _loadDrafts();
  }

  Future<List<DraftOrder>> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];
    try {
      return jsonList.map((json) => DraftOrder.fromJson(json)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Erreur chargement brouillons: $e');
      return [];
    }
  }

  Future<void> _saveDrafts(List<DraftOrder> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = drafts.map((d) => d.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  /// Sauvegarde le panier actuel comme brouillon
  Future<void> saveDraft({
    required Cart cart,
    required String restaurantName,
  }) async {
    final draft = DraftOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      restaurantName: restaurantName,
      items: cart.items,
      totalPrice: cart.totalPrice,
      createdAt: DateTime.now(),
    );

    final current = await _loadDrafts();
    current.insert(0, draft);
    await _saveDrafts(current);
    state = AsyncData(current);

    // Vider le panier backend
    await ref.read(cartControllerProvider.notifier).clearCart();
  }

  /// Restaure un brouillon dans le panier (ajoute chaque item)
  Future<void> restoreDraft(String draftId) async {
    final drafts = await _loadDrafts();
    final draft = drafts.firstWhere((d) => d.id == draftId);
    final cartController = ref.read(cartControllerProvider.notifier);

    for (final item in draft.items) {
      try {
        await cartController.addItem(
          variantId: item.variantId,
          quantity: item.quantite,
        );
      } catch (e) {
        debugPrint('Erreur ajout item ${item.product.nom}: $e');
      }
    }

    // Supprimer le brouillon apres restauration
    await deleteDraft(draftId);
  }

  /// Supprime un brouillon
  Future<void> deleteDraft(String draftId) async {
    final current = await _loadDrafts();
    current.removeWhere((d) => d.id == draftId);
    await _saveDrafts(current);
    state = AsyncData(current);
  }
}
