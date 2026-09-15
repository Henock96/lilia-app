// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adresse_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AdresseRepository)
final adresseRepositoryProvider = AdresseRepositoryProvider._();

final class AdresseRepositoryProvider
    extends $AsyncNotifierProvider<AdresseRepository, void> {
  AdresseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adresseRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adresseRepositoryHash();

  @$internal
  @override
  AdresseRepository create() => AdresseRepository();
}

String _$adresseRepositoryHash() => r'd5ec2b74f974b0ea2a0d702757137b844b0c7ea6';

abstract class _$AdresseRepository extends $AsyncNotifier<void> {
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
