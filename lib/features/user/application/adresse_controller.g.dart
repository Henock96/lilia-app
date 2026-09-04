// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adresse_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AdresseController)
final adresseControllerProvider = AdresseControllerProvider._();

final class AdresseControllerProvider
    extends $AsyncNotifierProvider<AdresseController, List<Adresse>> {
  AdresseControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adresseControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adresseControllerHash();

  @$internal
  @override
  AdresseController create() => AdresseController();
}

String _$adresseControllerHash() => r'e15146fd313b76bec0b85e95abcc770962bb32f6';

abstract class _$AdresseController extends $AsyncNotifier<List<Adresse>> {
  FutureOr<List<Adresse>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Adresse>>, List<Adresse>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Adresse>>, List<Adresse>>,
              AsyncValue<List<Adresse>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
