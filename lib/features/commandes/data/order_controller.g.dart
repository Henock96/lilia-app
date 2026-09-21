// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(UserOrders)
final userOrdersProvider = UserOrdersProvider._();

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
final class UserOrdersProvider
    extends $AsyncNotifierProvider<UserOrders, List<Order>> {
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
  UserOrdersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userOrdersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userOrdersHash();

  @$internal
  @override
  UserOrders create() => UserOrders();
}

String _$userOrdersHash() => r'5798fc46f253d7da73da63d4b268d5e30fa3247d';

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

abstract class _$UserOrders extends $AsyncNotifier<List<Order>> {
  FutureOr<List<Order>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Order>>, List<Order>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Order>>, List<Order>>,
              AsyncValue<List<Order>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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

@ProviderFor(orderDetail)
final orderDetailProvider = OrderDetailFamily._();

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

final class OrderDetailProvider
    extends $FunctionalProvider<AsyncValue<Order>, Order, FutureOr<Order>>
    with $FutureModifier<Order>, $FutureProvider<Order> {
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
  OrderDetailProvider._({
    required OrderDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'orderDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$orderDetailHash();

  @override
  String toString() {
    return r'orderDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Order> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Order> create(Ref ref) {
    final argument = this.argument as String;
    return orderDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OrderDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$orderDetailHash() => r'0a2aa15a81ae421ec807b163e7795e842f29e676';

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

final class OrderDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Order>, String> {
  OrderDetailFamily._()
    : super(
        retry: null,
        name: r'orderDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  OrderDetailProvider call(String orderId) =>
      OrderDetailProvider._(argument: orderId, from: this);

  @override
  String toString() => r'orderDetailProvider';
}
