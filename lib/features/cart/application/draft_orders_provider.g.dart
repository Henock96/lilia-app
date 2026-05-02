// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_orders_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DraftOrdersNotifier)
final draftOrdersProvider = DraftOrdersNotifierProvider._();

final class DraftOrdersNotifierProvider
    extends $AsyncNotifierProvider<DraftOrdersNotifier, List<DraftOrder>> {
  DraftOrdersNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftOrdersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftOrdersNotifierHash();

  @$internal
  @override
  DraftOrdersNotifier create() => DraftOrdersNotifier();
}

String _$draftOrdersNotifierHash() =>
    r'90069f518a101817f5fa29a4ac8d3a8bb4282096';

abstract class _$DraftOrdersNotifier extends $AsyncNotifier<List<DraftOrder>> {
  FutureOr<List<DraftOrder>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<DraftOrder>>, List<DraftOrder>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<DraftOrder>>, List<DraftOrder>>,
              AsyncValue<List<DraftOrder>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
