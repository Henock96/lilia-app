import 'package:lilia_app/services/analytics_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/models/order.dart';
import 'order_repository.dart';

part 'order_controller.g.dart';

/// L'historique des commandes, **paginé**.
///
/// ## Ce qui ne marchait pas
///
/// `build()` appelait `getMyOrders()` sans aucun paramètre. Le serveur applique
/// alors `limit = 20` (`PaginationQueryDto`), et personne ne demandait jamais
/// la page suivante : au-delà de la vingtième commande, l'historique d'un
/// client s'arrêtait — sans bouton, sans message, sans indice que quelque
/// chose manquait. Les trois onglets (« En cours », « Terminées »,
/// « Annulées ») découpent cette même page : un client actif ne voyait donc
/// qu'une poignée de commandes terminées.
///
/// ## L'invariant
///
/// L'état est **la liste cumulée**, dans l'ordre du serveur
/// (`createdAt desc`). [chargerPlus] y ajoute la page suivante en écartant
/// les identifiants déjà présents : une commande créée entre deux pages
/// décale la pagination et ferait sinon réapparaître une ligne de la page
/// précédente.
@riverpod
class UserOrders extends _$UserOrders {
  /// Page la plus récemment chargée, et nombre total annoncé par le serveur.
  int _page = 1;
  int _totalPages = 1;
  bool _chargementEnCours = false;

  @override
  Future<List<Order>> build() async {
    final premiere = await _repo.getMyOrders(page: 1);
    _page = premiere.page;
    _totalPages = premiere.totalPages;
    return premiere.orders;
  }

  OrderRepository get _repo => ref.read(orderRepositoryProvider.notifier);

  /// Reste-t-il des pages à demander ?
  bool get hasMore => _page < _totalPages;

  /// Un chargement de page suivante est en vol.
  bool get isLoadingMore => _chargementEnCours;

  /// Charge la page suivante et l'ajoute à la liste.
  ///
  /// Sans effet s'il n'y a plus rien à charger, ou si un chargement est déjà
  /// en vol : un défilement produit plusieurs notifications par seconde, et
  /// chacune redemanderait la même page.
  Future<void> chargerPlus() async {
    if (_chargementEnCours || !hasMore) return;
    _chargementEnCours = true;
    try {
      final suivante = await _repo.getMyOrders(page: _page + 1);
      if (!ref.mounted) return;

      final courant = state.value ?? const <Order>[];
      final connus = courant.map((o) => o.id).toSet();
      final nouvelles = suivante.orders.where((o) => !connus.contains(o.id));

      _page = suivante.page;
      _totalPages = suivante.totalPages;
      state = AsyncData([...courant, ...nouvelles]);
    } catch (_) {
      // Une page suivante qui échoue ne doit pas effacer celles déjà à
      // l'écran : on garde l'état, l'appelant peut réessayer en défilant.
      // Le compteur de page n'a pas avancé, donc rien n'est sauté.
    } finally {
      _chargementEnCours = false;
    }
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
    ref.invalidate(orderDetailProvider(orderId));
  }

  // Méthode pour annuler une commande.
  Future<void> cancelOrder(String orderId) async {
    final orderRepository = ref.read(orderRepositoryProvider.notifier);
    await orderRepository.cancelOrder(orderId);
    AnalyticsService.trackOrderCancelled(orderId: orderId);

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
    // L'écran de détail lit sa propre source : sans cette invalidation, il
    // continuerait d'afficher « En attente » et son bouton « Annuler ».
    ref.invalidate(orderDetailProvider(orderId));
  }
}

/// **Une** commande, lue par sa route dédiée.
///
/// ## Pourquoi ce provider existe
///
/// `OrderDetailPage` filtrait `userOrdersProvider` — c'est-à-dire la première
/// page de l'historique. Une commande absente de cette page produisait
/// « Cette commande n'est plus disponible ou a été retirée de votre liste »,
/// ce qui est faux : elle existe, elle est simplement plus ancienne que les
/// vingt dernières. Le cas se produit à chaque notification tardive, à chaque
/// consultation d'un ancien reçu, et pour tout client un peu fidèle.
///
/// `GET /orders/:id` existait côté serveur, et n'avait **aucun appelant**.
///
/// ## Rafraîchissement
///
/// Invalidé depuis les mêmes points que la liste : le push FCM
/// (`NotificationService`), l'événement `order:status` du WebSocket
/// (`DriverLocationController`), l'annulation et la suppression ci-dessus.
/// `autoDispose` : une commande consultée une fois n'a pas à rester en
/// mémoire.
@riverpod
Future<Order> orderDetail(Ref ref, String orderId) =>
    ref.read(orderRepositoryProvider.notifier).getOrder(orderId);
