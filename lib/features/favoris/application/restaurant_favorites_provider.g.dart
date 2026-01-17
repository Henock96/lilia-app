// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_favorites_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RestaurantFavorites)
final restaurantFavoritesProvider = RestaurantFavoritesProvider._();

final class RestaurantFavoritesProvider
    extends
        $AsyncNotifierProvider<RestaurantFavorites, List<RestaurantSummary>> {
  RestaurantFavoritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restaurantFavoritesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restaurantFavoritesHash();

  @$internal
  @override
  RestaurantFavorites create() => RestaurantFavorites();
}

String _$restaurantFavoritesHash() =>
    r'523fbe517aecc306918a6dd0aba121341438e4d3';

abstract class _$RestaurantFavorites
    extends $AsyncNotifier<List<RestaurantSummary>> {
  FutureOr<List<RestaurantSummary>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RestaurantSummary>>,
              List<RestaurantSummary>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RestaurantSummary>>,
                List<RestaurantSummary>
              >,
              AsyncValue<List<RestaurantSummary>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Provider pour vérifier si un restaurant est en favori (sync)

@ProviderFor(isRestaurantFavorite)
final isRestaurantFavoriteProvider = IsRestaurantFavoriteFamily._();

/// Provider pour vérifier si un restaurant est en favori (sync)

final class IsRestaurantFavoriteProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider pour vérifier si un restaurant est en favori (sync)
  IsRestaurantFavoriteProvider._({
    required IsRestaurantFavoriteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isRestaurantFavoriteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isRestaurantFavoriteHash();

  @override
  String toString() {
    return r'isRestaurantFavoriteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return isRestaurantFavorite(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsRestaurantFavoriteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isRestaurantFavoriteHash() =>
    r'ac1bb97461e12dab65f499aa1352171c8033c813';

/// Provider pour vérifier si un restaurant est en favori (sync)

final class IsRestaurantFavoriteFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  IsRestaurantFavoriteFamily._()
    : super(
        retry: null,
        name: r'isRestaurantFavoriteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour vérifier si un restaurant est en favori (sync)

  IsRestaurantFavoriteProvider call(String restaurantId) =>
      IsRestaurantFavoriteProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'isRestaurantFavoriteProvider';
}
