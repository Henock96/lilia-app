// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quartiers_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QuartiersRepository)
final quartiersRepositoryProvider = QuartiersRepositoryProvider._();

final class QuartiersRepositoryProvider
    extends $AsyncNotifierProvider<QuartiersRepository, void> {
  QuartiersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quartiersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quartiersRepositoryHash();

  @$internal
  @override
  QuartiersRepository create() => QuartiersRepository();
}

String _$quartiersRepositoryHash() =>
    r'74ea21be0db205c7bcca006133cbb90e5dfed0a1';

abstract class _$QuartiersRepository extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
