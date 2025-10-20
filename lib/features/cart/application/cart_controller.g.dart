// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cartRepositoryHash() => r'9dfca47f47d15cd4df54dcebdcf009d9816ce953';

/// See also [cartRepository].
@ProviderFor(cartRepository)
final cartRepositoryProvider = AutoDisposeProvider<CartRepository>.internal(
  cartRepository,
  name: r'cartRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cartRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CartRepositoryRef = AutoDisposeProviderRef<CartRepository>;
String _$cartControllerHash() => r'c956834ec9aedd71e81a20625522f2d8806c2d08';

/// See also [CartController].
@ProviderFor(CartController)
final cartControllerProvider =
    AutoDisposeStreamNotifierProvider<CartController, Cart?>.internal(
      CartController.new,
      name: r'cartControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cartControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CartController = AutoDisposeStreamNotifier<Cart?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
