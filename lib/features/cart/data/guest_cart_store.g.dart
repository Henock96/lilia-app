// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_cart_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `SharedPreferences` derrière un provider : c'est le seul point d'injection
/// des tests, qui posent `SharedPreferences.setMockInitialValues({})`.

@ProviderFor(guestCartStore)
final guestCartStoreProvider = GuestCartStoreProvider._();

/// `SharedPreferences` derrière un provider : c'est le seul point d'injection
/// des tests, qui posent `SharedPreferences.setMockInitialValues({})`.

final class GuestCartStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<GuestCartStore>,
          GuestCartStore,
          FutureOr<GuestCartStore>
        >
    with $FutureModifier<GuestCartStore>, $FutureProvider<GuestCartStore> {
  /// `SharedPreferences` derrière un provider : c'est le seul point d'injection
  /// des tests, qui posent `SharedPreferences.setMockInitialValues({})`.
  GuestCartStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestCartStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestCartStoreHash();

  @$internal
  @override
  $FutureProviderElement<GuestCartStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GuestCartStore> create(Ref ref) {
    return guestCartStore(ref);
  }
}

String _$guestCartStoreHash() => r'b7e0d0f5d4a36aebfb3bf8854030c213a4770627';
