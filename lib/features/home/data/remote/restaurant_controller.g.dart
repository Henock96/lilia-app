// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$restaurantControllerHash() =>
    r'0e753484c303eb266d9d0fbc08b9eca69791953d';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [restaurantController].
@ProviderFor(restaurantController)
const restaurantControllerProvider = RestaurantControllerFamily();

/// See also [restaurantController].
class RestaurantControllerFamily extends Family<AsyncValue<Restaurant>> {
  /// See also [restaurantController].
  const RestaurantControllerFamily();

  /// See also [restaurantController].
  RestaurantControllerProvider call(String restaurantId) {
    return RestaurantControllerProvider(restaurantId);
  }

  @override
  RestaurantControllerProvider getProviderOverride(
    covariant RestaurantControllerProvider provider,
  ) {
    return call(provider.restaurantId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'restaurantControllerProvider';
}

/// See also [restaurantController].
class RestaurantControllerProvider
    extends AutoDisposeFutureProvider<Restaurant> {
  /// See also [restaurantController].
  RestaurantControllerProvider(String restaurantId)
    : this._internal(
        (ref) =>
            restaurantController(ref as RestaurantControllerRef, restaurantId),
        from: restaurantControllerProvider,
        name: r'restaurantControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$restaurantControllerHash,
        dependencies: RestaurantControllerFamily._dependencies,
        allTransitiveDependencies:
            RestaurantControllerFamily._allTransitiveDependencies,
        restaurantId: restaurantId,
      );

  RestaurantControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.restaurantId,
  }) : super.internal();

  final String restaurantId;

  @override
  Override overrideWith(
    FutureOr<Restaurant> Function(RestaurantControllerRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RestaurantControllerProvider._internal(
        (ref) => create(ref as RestaurantControllerRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        restaurantId: restaurantId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Restaurant> createElement() {
    return _RestaurantControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantControllerProvider &&
        other.restaurantId == restaurantId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, restaurantId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RestaurantControllerRef on AutoDisposeFutureProviderRef<Restaurant> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _RestaurantControllerProviderElement
    extends AutoDisposeFutureProviderElement<Restaurant>
    with RestaurantControllerRef {
  _RestaurantControllerProviderElement(super.provider);

  @override
  String get restaurantId =>
      (origin as RestaurantControllerProvider).restaurantId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
