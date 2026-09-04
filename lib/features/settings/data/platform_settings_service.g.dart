// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_settings_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Charge les paramètres publics. En cas d'échec réseau, retombe sur
/// [PlatformSettings.fallback] plutôt que de bloquer le tunnel de commande.

@ProviderFor(platformSettings)
final platformSettingsProvider = PlatformSettingsProvider._();

/// Charge les paramètres publics. En cas d'échec réseau, retombe sur
/// [PlatformSettings.fallback] plutôt que de bloquer le tunnel de commande.

final class PlatformSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlatformSettings>,
          PlatformSettings,
          FutureOr<PlatformSettings>
        >
    with $FutureModifier<PlatformSettings>, $FutureProvider<PlatformSettings> {
  /// Charge les paramètres publics. En cas d'échec réseau, retombe sur
  /// [PlatformSettings.fallback] plutôt que de bloquer le tunnel de commande.
  PlatformSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformSettingsHash();

  @$internal
  @override
  $FutureProviderElement<PlatformSettings> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlatformSettings> create(Ref ref) {
    return platformSettings(ref);
  }
}

String _$platformSettingsHash() => r'89fada9399eddf8c19502dd71b57f117b781854c';
