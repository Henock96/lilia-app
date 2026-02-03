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
