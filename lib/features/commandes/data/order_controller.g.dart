// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserOrders)
final userOrdersProvider = UserOrdersProvider._();

final class UserOrdersProvider
    extends $AsyncNotifierProvider<UserOrders, List<Order>> {
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

String _$userOrdersHash() => r'd2ed611784ca67247c528f2737d52fad0a54ccc7';

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
