import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
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
    // C-12 (audit du 09/10/2026) : lecture **élément par élément**. Un seul
    // brouillon illisible (format d'une ancienne version, écriture
    // interrompue) faisait tomber le `try` global : la liste rendue était
    // vide, et le prochain enregistrement l'écrivait telle quelle — tous les
    // brouillons perdus pour un seul défectueux. Le défectueux est écarté,
    // les autres survivent.
    final drafts = <DraftOrder>[];
    for (final json in jsonList) {
      try {
        drafts.add(DraftOrder.fromJson(json));
      } catch (e) {
        logDebug('Brouillon illisible écarté : $e');
      }
    }
    return drafts..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

    // Ce qui n'a pas pu revenir dans le panier. Avant, un échec (article
    // épuisé, boutique fermée, panier d'un autre vendeur) n'était que
    // journalisé, et le brouillon était supprimé quand même : le client
    // perdait sa commande sans un mot.
    final restants = <CartItem>[];
    final noms = <String>[];
    String? premiereErreur;

    // Articles seuls — `awaitServer` : la restauration doit savoir lesquels
    // ont échoué. Sans lui, la boucle enverrait tout en parallèle et le
    // `catch` ne verrait rien.
    for (final item in draft.items.where((i) => i.menuId == null)) {
      try {
        await cartController.addItem(
          variantId: item.variantId,
          quantity: item.quantite,
          preview: CartItemPreview.fromCartItem(item),
          awaitServer: true,
        );
      } catch (e) {
        logDebug('Erreur ajout item ${item.product.nom}: $e');
        restants.add(item);
        noms.add(item.product.nom);
        premiereErreur ??= _message(e);
      }
    }

    // Menus — remis **en tant que menus** (prix du menu). Les rajouter ligne
    // à ligne comme des articles seuls les facturait au prix de chaque plat.
    final menus = <String, List<CartItem>>{};
    for (final item in draft.items.where((i) => i.menuId != null)) {
      menus.putIfAbsent(item.menuId!, () => []).add(item);
    }
    for (final entry in menus.entries) {
      final lignes = entry.value;
      try {
        await cartController.addMenu(
          menuId: entry.key,
          quantity: lignes.first.quantite,
        );
      } catch (e) {
        logDebug('Erreur ajout menu ${entry.key}: $e');
        restants.addAll(lignes);
        noms.add(lignes.first.menu?.nom ?? 'un menu');
        premiereErreur ??= _message(e);
      }
    }

    if (restants.isEmpty) {
      await deleteDraft(draftId);
      return;
    }

    // Échec partiel ou total : le brouillon garde ce qui n'est pas revenu,
    // pour ne rien dupliquer au prochain essai, ni rien perdre.
    final reste = DraftOrder(
      id: draft.id,
      restaurantName: draft.restaurantName,
      items: restants,
      totalPrice: Cart(
        id: '',
        userId: '',
        items: restants,
        createdAt: draft.createdAt,
        updatedAt: draft.createdAt,
      ).totalPrice,
      createdAt: draft.createdAt,
    );
    final drafts2 = await _loadDrafts();
    final i = drafts2.indexWhere((d) => d.id == draftId);
    if (i >= 0) drafts2[i] = reste;
    await _saveDrafts(drafts2);
    state = AsyncData(drafts2);

    final tout = restants.length == draft.items.length;
    throw CartException(
      '${tout ? 'Rien n\'a pu être remis dans le panier' : 'Non remis dans le panier'} '
      ': ${noms.join(', ')}. ${premiereErreur ?? ''} '
      'La commande en attente est conservée.'.replaceAll(RegExp(r'\s+'), ' '),
      code: 'DRAFT_PARTIAL_RESTORE',
    );
  }

  static String _message(Object e) {
    final m = e is CartException ? e.message : '';
    if (m.isEmpty) return '';
    return m.endsWith('.') ? m : '$m.';
  }

  /// Supprime un brouillon
  Future<void> deleteDraft(String draftId) async {
    final current = await _loadDrafts();
    current.removeWhere((d) => d.id == draftId);
    await _saveDrafts(current);
    state = AsyncData(current);
  }
}
