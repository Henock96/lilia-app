// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bannersList)
final bannersListProvider = BannersListProvider._();

final class BannersListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppBanner>>,
          List<AppBanner>,
          FutureOr<List<AppBanner>>
        >
    with $FutureModifier<List<AppBanner>>, $FutureProvider<List<AppBanner>> {
  BannersListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bannersListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bannersListHash();

  @$internal
  @override
  $FutureProviderElement<List<AppBanner>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppBanner>> create(Ref ref) {
    return bannersList(ref);
  }
}

String _$bannersListHash() => r'1912e91ba37c7949c10b794db04f3a739cf18b9e';
