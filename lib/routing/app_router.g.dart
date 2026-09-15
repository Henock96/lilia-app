// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Les observateurs de navigation, derrière un provider.
///
/// `AnalyticsService.observer` touche `FirebaseAnalytics.instance` à la
/// première lecture, et `SentryNavigatorObserver` son propre client. Construits
/// en dur dans le routeur, ils rendaient `routerProvider` **inconstructible
/// sans `Firebase.initializeApp()`** : la table de routes ne pouvait donc être
/// éprouvée par aucun test. Un point d'injection les remplace, sans rien
/// changer en production.

@ProviderFor(routerObservers)
final routerObserversProvider = RouterObserversProvider._();

/// Les observateurs de navigation, derrière un provider.
///
/// `AnalyticsService.observer` touche `FirebaseAnalytics.instance` à la
/// première lecture, et `SentryNavigatorObserver` son propre client. Construits
/// en dur dans le routeur, ils rendaient `routerProvider` **inconstructible
/// sans `Firebase.initializeApp()`** : la table de routes ne pouvait donc être
/// éprouvée par aucun test. Un point d'injection les remplace, sans rien
/// changer en production.

final class RouterObserversProvider
    extends
        $FunctionalProvider<
          List<NavigatorObserver>,
          List<NavigatorObserver>,
          List<NavigatorObserver>
        >
    with $Provider<List<NavigatorObserver>> {
  /// Les observateurs de navigation, derrière un provider.
  ///
  /// `AnalyticsService.observer` touche `FirebaseAnalytics.instance` à la
  /// première lecture, et `SentryNavigatorObserver` son propre client. Construits
  /// en dur dans le routeur, ils rendaient `routerProvider` **inconstructible
  /// sans `Firebase.initializeApp()`** : la table de routes ne pouvait donc être
  /// éprouvée par aucun test. Un point d'injection les remplace, sans rien
  /// changer en production.
  RouterObserversProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerObserversProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerObserversHash();

  @$internal
  @override
  $ProviderElement<List<NavigatorObserver>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<NavigatorObserver> create(Ref ref) {
    return routerObservers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<NavigatorObserver> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<NavigatorObserver>>(value),
    );
  }
}

String _$routerObserversHash() => r'69d4974cd5afe0737754d68090123dd6483e97a5';

/// **Une application, un `GoRouter`.**
///
/// ## Ce qui ne va plus
///
/// Le provider était `@riverpod` (donc `autoDispose`) et faisait
/// `ref.watch(authStateChangeProvider)` + `ref.watch(onboardingStatusProvider)`
/// dans son corps. Trois conséquences, pour une seule cause :
///
/// 1. **Trois à quatre routeurs par session.** Chaque émission du flux Firebase
///    (chargement → `null` → utilisateur à la connexion → `null` à la
///    déconnexion) reconstruisait le `GoRouter`. `MaterialApp.router` recevait
///    un nouveau `routerConfig`, l'arbre `Router` était reconstruit, **la pile
///    de navigation était perdue**.
/// 2. **Une fuite par instance.** `GoRouterRefreshStream` s'abonnait au flux
///    dans son constructeur ; le provider n'appelait `ref.onDispose` ni sur le
///    notifier, ni sur le routeur. Chaque ancienne instance gardait une
///    souscription vivante qui continuait d'appeler `notifyListeners()` sur un
///    routeur mort.
/// 3. **Double emploi.** `ref.watch` (qui reconstruit) et `refreshListenable`
///    (qui rafraîchit sans reconstruire) écoutaient la même source. Le second
///    suffit : c'est précisément le mécanisme prévu pour éviter le premier.
///
/// ## Ce qui est en place
///
/// ```text
/// Firebase Auth  ─┐
///                 ├─→ sessionPhase ─→ ValueNotifier ─→ refreshListenable
/// Onboarding     ─┘        │
///                          └─→ lu par `redirect` via ref.read
/// ```
///
/// `keepAlive` + aucun `ref.watch` dans le corps : **une seule instance**, pour
/// la vie de l'application. Le changement de session ne reconstruit plus rien,
/// il déclenche une réévaluation du `redirect`.
///
/// Le `ValueNotifier` ne notifie que sur **changement de valeur** : trois 401
/// simultanés produisent une seule transition `authenticated →
/// unauthenticated`, donc un seul rafraîchissement.

@ProviderFor(router)
final routerProvider = RouterProvider._();

/// **Une application, un `GoRouter`.**
///
/// ## Ce qui ne va plus
///
/// Le provider était `@riverpod` (donc `autoDispose`) et faisait
/// `ref.watch(authStateChangeProvider)` + `ref.watch(onboardingStatusProvider)`
/// dans son corps. Trois conséquences, pour une seule cause :
///
/// 1. **Trois à quatre routeurs par session.** Chaque émission du flux Firebase
///    (chargement → `null` → utilisateur à la connexion → `null` à la
///    déconnexion) reconstruisait le `GoRouter`. `MaterialApp.router` recevait
///    un nouveau `routerConfig`, l'arbre `Router` était reconstruit, **la pile
///    de navigation était perdue**.
/// 2. **Une fuite par instance.** `GoRouterRefreshStream` s'abonnait au flux
///    dans son constructeur ; le provider n'appelait `ref.onDispose` ni sur le
///    notifier, ni sur le routeur. Chaque ancienne instance gardait une
///    souscription vivante qui continuait d'appeler `notifyListeners()` sur un
///    routeur mort.
/// 3. **Double emploi.** `ref.watch` (qui reconstruit) et `refreshListenable`
///    (qui rafraîchit sans reconstruire) écoutaient la même source. Le second
///    suffit : c'est précisément le mécanisme prévu pour éviter le premier.
///
/// ## Ce qui est en place
///
/// ```text
/// Firebase Auth  ─┐
///                 ├─→ sessionPhase ─→ ValueNotifier ─→ refreshListenable
/// Onboarding     ─┘        │
///                          └─→ lu par `redirect` via ref.read
/// ```
///
/// `keepAlive` + aucun `ref.watch` dans le corps : **une seule instance**, pour
/// la vie de l'application. Le changement de session ne reconstruit plus rien,
/// il déclenche une réévaluation du `redirect`.
///
/// Le `ValueNotifier` ne notifie que sur **changement de valeur** : trois 401
/// simultanés produisent une seule transition `authenticated →
/// unauthenticated`, donc un seul rafraîchissement.

final class RouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// **Une application, un `GoRouter`.**
  ///
  /// ## Ce qui ne va plus
  ///
  /// Le provider était `@riverpod` (donc `autoDispose`) et faisait
  /// `ref.watch(authStateChangeProvider)` + `ref.watch(onboardingStatusProvider)`
  /// dans son corps. Trois conséquences, pour une seule cause :
  ///
  /// 1. **Trois à quatre routeurs par session.** Chaque émission du flux Firebase
  ///    (chargement → `null` → utilisateur à la connexion → `null` à la
  ///    déconnexion) reconstruisait le `GoRouter`. `MaterialApp.router` recevait
  ///    un nouveau `routerConfig`, l'arbre `Router` était reconstruit, **la pile
  ///    de navigation était perdue**.
  /// 2. **Une fuite par instance.** `GoRouterRefreshStream` s'abonnait au flux
  ///    dans son constructeur ; le provider n'appelait `ref.onDispose` ni sur le
  ///    notifier, ni sur le routeur. Chaque ancienne instance gardait une
  ///    souscription vivante qui continuait d'appeler `notifyListeners()` sur un
  ///    routeur mort.
  /// 3. **Double emploi.** `ref.watch` (qui reconstruit) et `refreshListenable`
  ///    (qui rafraîchit sans reconstruire) écoutaient la même source. Le second
  ///    suffit : c'est précisément le mécanisme prévu pour éviter le premier.
  ///
  /// ## Ce qui est en place
  ///
  /// ```text
  /// Firebase Auth  ─┐
  ///                 ├─→ sessionPhase ─→ ValueNotifier ─→ refreshListenable
  /// Onboarding     ─┘        │
  ///                          └─→ lu par `redirect` via ref.read
  /// ```
  ///
  /// `keepAlive` + aucun `ref.watch` dans le corps : **une seule instance**, pour
  /// la vie de l'application. Le changement de session ne reconstruit plus rien,
  /// il déclenche une réévaluation du `redirect`.
  ///
  /// Le `ValueNotifier` ne notifie que sur **changement de valeur** : trois 401
  /// simultanés produisent une seule transition `authenticated →
  /// unauthenticated`, donc un seul rafraîchissement.
  RouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return router(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$routerHash() => r'f98fa11f00fc2bd5a8be9a8d0ec66f5a74fe1253';
