import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/draft_order.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';
import '../../auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/core/log.dart';

part 'draft_orders_provider.g.dart';

const _storageKey = 'draft_orders';

@Riverpod(keepAlive: true)
class DraftOrdersNotifier extends _$DraftOrdersNotifier {
  /// Clé du compte connecté — `draft_orders__<uid>`.
  ///
  /// Un brouillon nomme un vendeur, liste des articles et porte un montant :
  /// sous une clé globale, il passait d'un compte à l'autre sur un téléphone
  /// partagé. Voir `user_scoped_prefs.dart`.
  String get _cle => cleParCompte(
        _storageKey,
        ref.read(authRepositoryProvider).currentUser?.uid,
      );

  @override
  Future<List<DraftOrder>> build() async {
    return _loadDrafts();
  }

  Future<List<DraftOrder>> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_cle) ?? [];
    try {
      return jsonList.map((json) => DraftOrder.fromJson(json)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      logDebug('Erreur chargement brouillons: $e');
      return [];
    }
  }

  Future<void> _saveDrafts(List<DraftOrder> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = drafts.map((d) => d.toJson()).toList();
    await prefs.setStringList(_cle, jsonList);
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
    // Recherche null-safe : le brouillon a pu être supprimé entre l'affichage
    // et la restauration → ne pas crasher (StateError) sur un firstWhere sec.
    final matches = drafts.where((d) => d.id == draftId);
    if (matches.isEmpty) {
      logDebug('Brouillon $draftId introuvable — restauration ignorée');
      return;
    }
    final draft = matches.first;
    final cartController = ref.read(cartControllerProvider.notifier);

    for (final item in draft.items) {
      try {
        // `awaitServer` : la restauration ajoute les articles un par un et
        // doit savoir lesquels ont échoué. Sans lui, la boucle enverrait tous
        // les articles en parallèle et le `catch` ci-dessous ne verrait rien.
        await cartController.addItem(
          variantId: item.variantId,
          quantity: item.quantite,
          preview: CartItemPreview.fromCartItem(item),
          awaitServer: true,
        );
      } catch (e) {
        logDebug('Erreur ajout item ${item.product.nom}: $e');
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
