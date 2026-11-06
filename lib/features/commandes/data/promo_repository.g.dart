// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promo_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PromoRepository)
final promoRepositoryProvider = PromoRepositoryProvider._();

final class PromoRepositoryProvider
    extends $AsyncNotifierProvider<PromoRepository, void> {
  PromoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promoRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promoRepositoryHash();

  @$internal
  @override
  PromoRepository create() => PromoRepository();
}

String _$promoRepositoryHash() => r'fe562e557cf7aea7f0b77806a8f0dc9b2e93aa88';

abstract class _$PromoRepository extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
