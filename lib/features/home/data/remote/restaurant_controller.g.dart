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

/// Provider pour récupérer un restaurant spécifique avec ses produits
/// keepAlive: true pour garder les données en cache quand on quitte la page

@ProviderFor(restaurantController)
final restaurantControllerProvider = RestaurantControllerFamily._();

/// Provider pour récupérer un restaurant spécifique avec ses produits
/// keepAlive: true pour garder les données en cache quand on quitte la page

final class RestaurantControllerProvider
    extends
        $FunctionalProvider<
          AsyncValue<Restaurant>,
          Restaurant,
          FutureOr<Restaurant>
        >
    with $FutureModifier<Restaurant>, $FutureProvider<Restaurant> {
  /// Provider pour récupérer un restaurant spécifique avec ses produits
  /// keepAlive: true pour garder les données en cache quand on quitte la page
  RestaurantControllerProvider._({
    required RestaurantControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'restaurantControllerProvider',
         isAutoDispose: false,
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
    r'e79edf359d8c21ec50eccf78b55afe25b90622bc';

/// Provider pour récupérer un restaurant spécifique avec ses produits
/// keepAlive: true pour garder les données en cache quand on quitte la page

final class RestaurantControllerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Restaurant>, String> {
  RestaurantControllerFamily._()
    : super(
        retry: null,
        name: r'restaurantControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Provider pour récupérer un restaurant spécifique avec ses produits
  /// keepAlive: true pour garder les données en cache quand on quitte la page

  RestaurantControllerProvider call(String restaurantId) =>
      RestaurantControllerProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'restaurantControllerProvider';
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
