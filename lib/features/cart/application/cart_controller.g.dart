// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cartRepository)
final cartRepositoryProvider = CartRepositoryProvider._();

final class CartRepositoryProvider
    extends $FunctionalProvider<CartRepository, CartRepository, CartRepository>
    with $Provider<CartRepository> {
  CartRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartRepositoryHash();

  @$internal
  @override
  $ProviderElement<CartRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CartRepository create(Ref ref) {
    return cartRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CartRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CartRepository>(value),
    );
  }
}

String _$cartRepositoryHash() => r'fea908e31a13a38fdb6590b5f0c3342caef18590';

/// Canal des échecs de synchronisation du panier.
///
/// Il existe parce que les mutations rendent la main **avant** le réseau : un
/// échec ne peut donc plus être levé vers l'appelant, qui a déjà affiché sa
/// confirmation et n'écoute plus. Un unique `ref.listen` dans la coque de
/// navigation le transforme en message — voir `BottomNavigationPage`.

@ProviderFor(CartSyncFailures)
final cartSyncFailuresProvider = CartSyncFailuresProvider._();

/// Canal des échecs de synchronisation du panier.
///
/// Il existe parce que les mutations rendent la main **avant** le réseau : un
/// échec ne peut donc plus être levé vers l'appelant, qui a déjà affiché sa
/// confirmation et n'écoute plus. Un unique `ref.listen` dans la coque de
/// navigation le transforme en message — voir `BottomNavigationPage`.
final class CartSyncFailuresProvider
    extends $NotifierProvider<CartSyncFailures, CartSyncFailure?> {
  /// Canal des échecs de synchronisation du panier.
  ///
  /// Il existe parce que les mutations rendent la main **avant** le réseau : un
  /// échec ne peut donc plus être levé vers l'appelant, qui a déjà affiché sa
  /// confirmation et n'écoute plus. Un unique `ref.listen` dans la coque de
  /// navigation le transforme en message — voir `BottomNavigationPage`.
  CartSyncFailuresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartSyncFailuresProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartSyncFailuresHash();

  @$internal
  @override
  CartSyncFailures create() => CartSyncFailures();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CartSyncFailure? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CartSyncFailure?>(value),
    );
  }
}

String _$cartSyncFailuresHash() => r'7c8a35812a509dc4d88d7f18904c59da48758bca';

/// Canal des échecs de synchronisation du panier.
///
/// Il existe parce que les mutations rendent la main **avant** le réseau : un
/// échec ne peut donc plus être levé vers l'appelant, qui a déjà affiché sa
/// confirmation et n'écoute plus. Un unique `ref.listen` dans la coque de
/// navigation le transforme en message — voir `BottomNavigationPage`.

abstract class _$CartSyncFailures extends $Notifier<CartSyncFailure?> {
  CartSyncFailure? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CartSyncFailure?, CartSyncFailure?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CartSyncFailure?, CartSyncFailure?>,
              CartSyncFailure?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// État du panier, mises à jour optimistes et réconciliation avec le serveur.
///
/// ## Pourquoi un `AsyncNotifier` et non plus un `Stream`
///
/// Le contrôleur observait auparavant un `StreamController` détenu par le
/// repository : il n'était propriétaire de rien, et il n'existait donc **aucun
/// endroit** où prendre un instantané avant mutation, appliquer un changement
/// local puis le défaire. C'est ce vide qui rendait le retour visuel
/// dépendant du réseau.
///
/// Le type exposé aux widgets est inchangé — `AsyncValue<Cart?>` — donc
/// `ref.watch(cartControllerProvider)`, `.value`, `.when(...)` et
/// `ref.invalidate(...)` se comportent exactement comme avant.
///
/// ## Le contrat des mutations optimistes
///
/// `addItem`, `updateItemQuantity` et `removeItem` **rendent la main dès que
/// l'état local est à jour** (moins d'une milliseconde). Le réseau se poursuit
/// en arrière-plan. Conséquences, à connaître avant d'appeler :
///
/// - une erreur de **validation locale** est levée à l'appelant, de façon
///   synchrone — il peut la présenter comme avant ;
/// - un échec **réseau** ne peut plus l'être : il défait le changement et part
///   dans [cartSyncFailuresProvider].
///
/// Passer `awaitServer: true` rétablit l'attente complète, pour les appelants
/// qui enchaînent des opérations et ont besoin de l'ordre (restauration d'un
/// brouillon).
///
/// Les **menus** n'ont pas de version optimiste : un menu est un groupe de
/// lignes dont la composition n'est connue que du serveur. Les fabriquer
/// localement inventerait un contenu. Ils bénéficient malgré tout de P-01 et
/// ne coûtent plus qu'un aller-retour.
///
/// ## Pourquoi `keepAlive`
///
/// Le provider était en `autoDispose`, contre la convention du projet qui
/// range le panier avec l'authentification et les notifications. C'était sans
/// conséquence visible tant que l'état venait du serveur à chaque lecture ;
/// ça ne l'est plus. L'ajout se fait depuis l'écran vendeur, où **aucun
/// widget n'observe le panier** : le provider y serait détruit aussitôt après
/// la mutation, emportant l'état optimiste et la requête en vol avec lui.
///
/// La destruction reste explicite et voulue — `ref.invalidate(
/// cartControllerProvider)` à la déconnexion et au changement de compte
/// (`auth_controller`), inchangé.

@ProviderFor(CartController)
final cartControllerProvider = CartControllerProvider._();

/// État du panier, mises à jour optimistes et réconciliation avec le serveur.
///
/// ## Pourquoi un `AsyncNotifier` et non plus un `Stream`
///
/// Le contrôleur observait auparavant un `StreamController` détenu par le
/// repository : il n'était propriétaire de rien, et il n'existait donc **aucun
/// endroit** où prendre un instantané avant mutation, appliquer un changement
/// local puis le défaire. C'est ce vide qui rendait le retour visuel
/// dépendant du réseau.
///
/// Le type exposé aux widgets est inchangé — `AsyncValue<Cart?>` — donc
/// `ref.watch(cartControllerProvider)`, `.value`, `.when(...)` et
/// `ref.invalidate(...)` se comportent exactement comme avant.
///
/// ## Le contrat des mutations optimistes
///
/// `addItem`, `updateItemQuantity` et `removeItem` **rendent la main dès que
/// l'état local est à jour** (moins d'une milliseconde). Le réseau se poursuit
/// en arrière-plan. Conséquences, à connaître avant d'appeler :
///
/// - une erreur de **validation locale** est levée à l'appelant, de façon
///   synchrone — il peut la présenter comme avant ;
/// - un échec **réseau** ne peut plus l'être : il défait le changement et part
///   dans [cartSyncFailuresProvider].
///
/// Passer `awaitServer: true` rétablit l'attente complète, pour les appelants
/// qui enchaînent des opérations et ont besoin de l'ordre (restauration d'un
/// brouillon).
///
/// Les **menus** n'ont pas de version optimiste : un menu est un groupe de
/// lignes dont la composition n'est connue que du serveur. Les fabriquer
/// localement inventerait un contenu. Ils bénéficient malgré tout de P-01 et
/// ne coûtent plus qu'un aller-retour.
///
/// ## Pourquoi `keepAlive`
///
/// Le provider était en `autoDispose`, contre la convention du projet qui
/// range le panier avec l'authentification et les notifications. C'était sans
/// conséquence visible tant que l'état venait du serveur à chaque lecture ;
/// ça ne l'est plus. L'ajout se fait depuis l'écran vendeur, où **aucun
/// widget n'observe le panier** : le provider y serait détruit aussitôt après
/// la mutation, emportant l'état optimiste et la requête en vol avec lui.
///
/// La destruction reste explicite et voulue — `ref.invalidate(
/// cartControllerProvider)` à la déconnexion et au changement de compte
/// (`auth_controller`), inchangé.
final class CartControllerProvider
    extends $AsyncNotifierProvider<CartController, Cart?> {
  /// État du panier, mises à jour optimistes et réconciliation avec le serveur.
  ///
  /// ## Pourquoi un `AsyncNotifier` et non plus un `Stream`
  ///
  /// Le contrôleur observait auparavant un `StreamController` détenu par le
  /// repository : il n'était propriétaire de rien, et il n'existait donc **aucun
  /// endroit** où prendre un instantané avant mutation, appliquer un changement
  /// local puis le défaire. C'est ce vide qui rendait le retour visuel
  /// dépendant du réseau.
  ///
  /// Le type exposé aux widgets est inchangé — `AsyncValue<Cart?>` — donc
  /// `ref.watch(cartControllerProvider)`, `.value`, `.when(...)` et
  /// `ref.invalidate(...)` se comportent exactement comme avant.
  ///
  /// ## Le contrat des mutations optimistes
  ///
  /// `addItem`, `updateItemQuantity` et `removeItem` **rendent la main dès que
  /// l'état local est à jour** (moins d'une milliseconde). Le réseau se poursuit
  /// en arrière-plan. Conséquences, à connaître avant d'appeler :
  ///
  /// - une erreur de **validation locale** est levée à l'appelant, de façon
  ///   synchrone — il peut la présenter comme avant ;
  /// - un échec **réseau** ne peut plus l'être : il défait le changement et part
  ///   dans [cartSyncFailuresProvider].
  ///
  /// Passer `awaitServer: true` rétablit l'attente complète, pour les appelants
  /// qui enchaînent des opérations et ont besoin de l'ordre (restauration d'un
  /// brouillon).
  ///
  /// Les **menus** n'ont pas de version optimiste : un menu est un groupe de
  /// lignes dont la composition n'est connue que du serveur. Les fabriquer
  /// localement inventerait un contenu. Ils bénéficient malgré tout de P-01 et
  /// ne coûtent plus qu'un aller-retour.
  ///
  /// ## Pourquoi `keepAlive`
  ///
  /// Le provider était en `autoDispose`, contre la convention du projet qui
  /// range le panier avec l'authentification et les notifications. C'était sans
  /// conséquence visible tant que l'état venait du serveur à chaque lecture ;
  /// ça ne l'est plus. L'ajout se fait depuis l'écran vendeur, où **aucun
  /// widget n'observe le panier** : le provider y serait détruit aussitôt après
  /// la mutation, emportant l'état optimiste et la requête en vol avec lui.
  ///
  /// La destruction reste explicite et voulue — `ref.invalidate(
  /// cartControllerProvider)` à la déconnexion et au changement de compte
  /// (`auth_controller`), inchangé.
  CartControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartControllerHash();

  @$internal
  @override
  CartController create() => CartController();
}

String _$cartControllerHash() => r'02ee32b482dc585cad0665a5a171a589fdfa8125';

/// État du panier, mises à jour optimistes et réconciliation avec le serveur.
///
/// ## Pourquoi un `AsyncNotifier` et non plus un `Stream`
///
/// Le contrôleur observait auparavant un `StreamController` détenu par le
/// repository : il n'était propriétaire de rien, et il n'existait donc **aucun
/// endroit** où prendre un instantané avant mutation, appliquer un changement
/// local puis le défaire. C'est ce vide qui rendait le retour visuel
/// dépendant du réseau.
///
/// Le type exposé aux widgets est inchangé — `AsyncValue<Cart?>` — donc
/// `ref.watch(cartControllerProvider)`, `.value`, `.when(...)` et
/// `ref.invalidate(...)` se comportent exactement comme avant.
///
/// ## Le contrat des mutations optimistes
///
/// `addItem`, `updateItemQuantity` et `removeItem` **rendent la main dès que
/// l'état local est à jour** (moins d'une milliseconde). Le réseau se poursuit
/// en arrière-plan. Conséquences, à connaître avant d'appeler :
///
/// - une erreur de **validation locale** est levée à l'appelant, de façon
///   synchrone — il peut la présenter comme avant ;
/// - un échec **réseau** ne peut plus l'être : il défait le changement et part
///   dans [cartSyncFailuresProvider].
///
/// Passer `awaitServer: true` rétablit l'attente complète, pour les appelants
/// qui enchaînent des opérations et ont besoin de l'ordre (restauration d'un
/// brouillon).
///
/// Les **menus** n'ont pas de version optimiste : un menu est un groupe de
/// lignes dont la composition n'est connue que du serveur. Les fabriquer
/// localement inventerait un contenu. Ils bénéficient malgré tout de P-01 et
/// ne coûtent plus qu'un aller-retour.
///
/// ## Pourquoi `keepAlive`
///
/// Le provider était en `autoDispose`, contre la convention du projet qui
/// range le panier avec l'authentification et les notifications. C'était sans
/// conséquence visible tant que l'état venait du serveur à chaque lecture ;
/// ça ne l'est plus. L'ajout se fait depuis l'écran vendeur, où **aucun
/// widget n'observe le panier** : le provider y serait détruit aussitôt après
/// la mutation, emportant l'état optimiste et la requête en vol avec lui.
///
/// La destruction reste explicite et voulue — `ref.invalidate(
/// cartControllerProvider)` à la déconnexion et au changement de compte
/// (`auth_controller`), inchangé.

abstract class _$CartController extends $AsyncNotifier<Cart?> {
  FutureOr<Cart?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Cart?>, Cart?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Cart?>, Cart?>,
              AsyncValue<Cart?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
