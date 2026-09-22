// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appUpdateService)
final appUpdateServiceProvider = AppUpdateServiceProvider._();

final class AppUpdateServiceProvider
    extends
        $FunctionalProvider<
          AppUpdateService,
          AppUpdateService,
          AppUpdateService
        >
    with $Provider<AppUpdateService> {
  AppUpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateServiceHash();

  @$internal
  @override
  $ProviderElement<AppUpdateService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppUpdateService create(Ref ref) {
    return appUpdateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppUpdateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppUpdateService>(value),
    );
  }
}

String _$appUpdateServiceHash() => r'ddbca48a1360c6b90cc6e93ba41742b64936cc6a';

/// Version installée, lue une fois dans le binaire (`package_info_plus`).

@ProviderFor(installedAppVersion)
final installedAppVersionProvider = InstalledAppVersionProvider._();

/// Version installée, lue une fois dans le binaire (`package_info_plus`).

final class InstalledAppVersionProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppVersion?>,
          AppVersion?,
          FutureOr<AppVersion?>
        >
    with $FutureModifier<AppVersion?>, $FutureProvider<AppVersion?> {
  /// Version installée, lue une fois dans le binaire (`package_info_plus`).
  InstalledAppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedAppVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedAppVersionHash();

  @$internal
  @override
  $FutureProviderElement<AppVersion?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppVersion?> create(Ref ref) {
    return installedAppVersion(ref);
  }
}

String _$installedAppVersionHash() =>
    r'0f655694158d24ccbaf4d1304079e5faa4e8ef45';

/// Fournit l'état calculé de la mise à jour courante à partir de PlatformSettings.

@ProviderFor(appUpdateInfo)
final appUpdateInfoProvider = AppUpdateInfoProvider._();

/// Fournit l'état calculé de la mise à jour courante à partir de PlatformSettings.

final class AppUpdateInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppUpdateInfo>,
          AppUpdateInfo,
          FutureOr<AppUpdateInfo>
        >
    with $FutureModifier<AppUpdateInfo>, $FutureProvider<AppUpdateInfo> {
  /// Fournit l'état calculé de la mise à jour courante à partir de PlatformSettings.
  AppUpdateInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateInfoHash();

  @$internal
  @override
  $FutureProviderElement<AppUpdateInfo> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppUpdateInfo> create(Ref ref) {
    return appUpdateInfo(ref);
  }
}

String _$appUpdateInfoHash() => r'beaa57d762101de5cb64d3449131ae911e4b8e7c';
