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

String _$appUpdateInfoHash() => r'e0752175de499ccd1604cf3e150140238e0b6bb3';
