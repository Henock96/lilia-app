// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider pour récupérer la liste de tous les restaurants

@ProviderFor(restaurantsList)
final restaurantsListProvider = RestaurantsListProvider._();

/// Provider pour récupérer la liste de tous les restaurants

final class RestaurantsListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RestaurantSummary>>,
          List<RestaurantSummary>,
          FutureOr<List<RestaurantSummary>>
        >
    with
        $FutureModifier<List<RestaurantSummary>>,
        $FutureProvider<List<RestaurantSummary>> {
  /// Provider pour récupérer la liste de tous les restaurants
  RestaurantsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restaurantsListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restaurantsListHash();

  @$internal
  @override
  $FutureProviderElement<List<RestaurantSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RestaurantSummary>> create(Ref ref) {
    return restaurantsList(ref);
  }
}

String _$restaurantsListHash() => r'9de93e98d8872c1becac3e24bdda1238ed1e3440';

/// **La carte d'un vendeur**, avec un cache borné.
///
/// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
///
/// | Geste | Effet |
/// |---|---|
/// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
/// | ouverture après `kMenuCacheTtl` | nouvel appel |
/// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
/// | tirer pour rafraîchir | nouvel appel, immédiat |
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.

@ProviderFor(restaurantController)
final restaurantControllerProvider = RestaurantControllerFamily._();

/// **La carte d'un vendeur**, avec un cache borné.
///
/// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
///
/// | Geste | Effet |
/// |---|---|
/// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
/// | ouverture après `kMenuCacheTtl` | nouvel appel |
/// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
/// | tirer pour rafraîchir | nouvel appel, immédiat |
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.

final class RestaurantControllerProvider
    extends
        $FunctionalProvider<
          AsyncValue<Restaurant>,
          Restaurant,
          FutureOr<Restaurant>
        >
    with $FutureModifier<Restaurant>, $FutureProvider<Restaurant> {
  /// **La carte d'un vendeur**, avec un cache borné.
  ///
  /// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
  ///
  /// | Geste | Effet |
  /// |---|---|
  /// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
  /// | ouverture après `kMenuCacheTtl` | nouvel appel |
  /// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
  /// | tirer pour rafraîchir | nouvel appel, immédiat |
  ///
  /// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
  /// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
  /// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
  /// quoi un provider détruit tôt laisserait un `Timer` en vol.
  RestaurantControllerProvider._({
    required RestaurantControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'restaurantControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$restaurantControllerHash();

  @override
  String toString() {
    return r'restaurantControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Restaurant> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Restaurant> create(Ref ref) {
    final argument = this.argument as String;
    return restaurantController(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$restaurantControllerHash() =>
    r'9a5004f49ea3bf85269ba4df2435d47e447add23';

/// **La carte d'un vendeur**, avec un cache borné.
///
/// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
///
/// | Geste | Effet |
/// |---|---|
/// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
/// | ouverture après `kMenuCacheTtl` | nouvel appel |
/// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
/// | tirer pour rafraîchir | nouvel appel, immédiat |
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.

final class RestaurantControllerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Restaurant>, String> {
  RestaurantControllerFamily._()
    : super(
        retry: null,
        name: r'restaurantControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// **La carte d'un vendeur**, avec un cache borné.
  ///
  /// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
  ///
  /// | Geste | Effet |
  /// |---|---|
  /// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
  /// | ouverture après `kMenuCacheTtl` | nouvel appel |
  /// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
  /// | tirer pour rafraîchir | nouvel appel, immédiat |
  ///
  /// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
  /// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
  /// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
  /// quoi un provider détruit tôt laisserait un `Timer` en vol.

  RestaurantControllerProvider call(String restaurantId) =>
      RestaurantControllerProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'restaurantControllerProvider';
}

/// Horodatage qui ne change qu'aux reprises **tardives** de l'application.
///
/// ## Pourquoi la durée de vie ne suffit pas
///
/// Un téléphone posé deux heures avec l'écran de la boutique ouvert laisse le
/// widget monté : le minuteur aura bien relâché le lien, mais rien ne
/// redemandera la donnée tant que l'utilisateur ne navigue pas. Or reprendre
/// l'application est **exactement** le moment où il regarde à nouveau le menu.
///
/// ## Pourquoi « tardives » et pas « toutes »
///
/// Publier un horodatage à chaque reprise rechargerait la carte après un simple
/// aller-retour vers les notifications. On ne publie donc que si l'écart dépasse
/// [kMenuCacheTtl] — en dessous, la donnée est encore bonne, et Riverpod ne voit
/// aucun changement de valeur, donc ne reconstruit rien.

@ProviderFor(StaleForegroundStamp)
final staleForegroundStampProvider = StaleForegroundStampProvider._();

/// Horodatage qui ne change qu'aux reprises **tardives** de l'application.
///
/// ## Pourquoi la durée de vie ne suffit pas
///
/// Un téléphone posé deux heures avec l'écran de la boutique ouvert laisse le
/// widget monté : le minuteur aura bien relâché le lien, mais rien ne
/// redemandera la donnée tant que l'utilisateur ne navigue pas. Or reprendre
/// l'application est **exactement** le moment où il regarde à nouveau le menu.
///
/// ## Pourquoi « tardives » et pas « toutes »
///
/// Publier un horodatage à chaque reprise rechargerait la carte après un simple
/// aller-retour vers les notifications. On ne publie donc que si l'écart dépasse
/// [kMenuCacheTtl] — en dessous, la donnée est encore bonne, et Riverpod ne voit
/// aucun changement de valeur, donc ne reconstruit rien.
final class StaleForegroundStampProvider
    extends $NotifierProvider<StaleForegroundStamp, DateTime> {
  /// Horodatage qui ne change qu'aux reprises **tardives** de l'application.
  ///
  /// ## Pourquoi la durée de vie ne suffit pas
  ///
  /// Un téléphone posé deux heures avec l'écran de la boutique ouvert laisse le
  /// widget monté : le minuteur aura bien relâché le lien, mais rien ne
  /// redemandera la donnée tant que l'utilisateur ne navigue pas. Or reprendre
  /// l'application est **exactement** le moment où il regarde à nouveau le menu.
  ///
  /// ## Pourquoi « tardives » et pas « toutes »
  ///
  /// Publier un horodatage à chaque reprise rechargerait la carte après un simple
  /// aller-retour vers les notifications. On ne publie donc que si l'écart dépasse
  /// [kMenuCacheTtl] — en dessous, la donnée est encore bonne, et Riverpod ne voit
  /// aucun changement de valeur, donc ne reconstruit rien.
  StaleForegroundStampProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'staleForegroundStampProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$staleForegroundStampHash();

  @$internal
  @override
  StaleForegroundStamp create() => StaleForegroundStamp();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$staleForegroundStampHash() =>
    r'3cab9c77f5e76bffadcb098bd960b392c3e06a81';

/// Horodatage qui ne change qu'aux reprises **tardives** de l'application.
///
/// ## Pourquoi la durée de vie ne suffit pas
///
/// Un téléphone posé deux heures avec l'écran de la boutique ouvert laisse le
/// widget monté : le minuteur aura bien relâché le lien, mais rien ne
/// redemandera la donnée tant que l'utilisateur ne navigue pas. Or reprendre
/// l'application est **exactement** le moment où il regarde à nouveau le menu.
///
/// ## Pourquoi « tardives » et pas « toutes »
///
/// Publier un horodatage à chaque reprise rechargerait la carte après un simple
/// aller-retour vers les notifications. On ne publie donc que si l'écart dépasse
/// [kMenuCacheTtl] — en dessous, la donnée est encore bonne, et Riverpod ne voit
/// aucun changement de valeur, donc ne reconstruit rien.

abstract class _$StaleForegroundStamp extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].

@ProviderFor(MarketplaceFilter)
final marketplaceFilterProvider = MarketplaceFilterProvider._();

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].
final class MarketplaceFilterProvider
    extends $NotifierProvider<MarketplaceFilter, VendorType?> {
  /// Filtre vendor type courant pour le marketplace (LIL-117).
  /// `null` = "Tous" (pas de filtre). Watched par [vendorsList].
  MarketplaceFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceFilterHash();

  @$internal
  @override
  MarketplaceFilter create() => MarketplaceFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VendorType? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VendorType?>(value),
    );
  }
}

String _$marketplaceFilterHash() => r'9de4b216d1b685124fca3e14dc2d727b34f1c92c';

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].

abstract class _$MarketplaceFilter extends $Notifier<VendorType?> {
  VendorType? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VendorType?, VendorType?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VendorType?, VendorType?>,
              VendorType?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
/// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
/// Riverpod rebuilde et refetch automatiquement.

@ProviderFor(vendorsList)
final vendorsListProvider = VendorsListProvider._();

/// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
/// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
/// Riverpod rebuilde et refetch automatiquement.

final class VendorsListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RestaurantSummary>>,
          List<RestaurantSummary>,
          FutureOr<List<RestaurantSummary>>
        >
    with
        $FutureModifier<List<RestaurantSummary>>,
        $FutureProvider<List<RestaurantSummary>> {
  /// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
  /// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
  /// Riverpod rebuilde et refetch automatiquement.
  VendorsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vendorsListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vendorsListHash();

  @$internal
  @override
  $FutureProviderElement<List<RestaurantSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RestaurantSummary>> create(Ref ref) {
    return vendorsList(ref);
  }
}

String _$vendorsListHash() => r'cb4a9ab64c802ace69bd921ee91b1c46fa998b01';
