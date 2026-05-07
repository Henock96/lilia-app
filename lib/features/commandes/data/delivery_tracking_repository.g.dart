// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_tracking_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider qui poll la position du livreur toutes les 10 secondes.
/// Utilisé côté client sur la page détail commande (status EN_ROUTE).

@ProviderFor(DriverLocationController)
final driverLocationControllerProvider = DriverLocationControllerFamily._();

/// Provider qui poll la position du livreur toutes les 10 secondes.
/// Utilisé côté client sur la page détail commande (status EN_ROUTE).
final class DriverLocationControllerProvider
    extends $AsyncNotifierProvider<DriverLocationController, DriverLocation?> {
  /// Provider qui poll la position du livreur toutes les 10 secondes.
  /// Utilisé côté client sur la page détail commande (status EN_ROUTE).
  DriverLocationControllerProvider._({
    required DriverLocationControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'driverLocationControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$driverLocationControllerHash();

  @override
  String toString() {
    return r'driverLocationControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DriverLocationController create() => DriverLocationController();

  @override
  bool operator ==(Object other) {
    return other is DriverLocationControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$driverLocationControllerHash() =>
    r'fbfa3fe1647bebbb0f8766df6a2a067a49a81088';

/// Provider qui poll la position du livreur toutes les 10 secondes.
/// Utilisé côté client sur la page détail commande (status EN_ROUTE).

final class DriverLocationControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          DriverLocationController,
          AsyncValue<DriverLocation?>,
          DriverLocation?,
          FutureOr<DriverLocation?>,
          String
        > {
  DriverLocationControllerFamily._()
    : super(
        retry: null,
        name: r'driverLocationControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider qui poll la position du livreur toutes les 10 secondes.
  /// Utilisé côté client sur la page détail commande (status EN_ROUTE).

  DriverLocationControllerProvider call(String orderId) =>
      DriverLocationControllerProvider._(argument: orderId, from: this);

  @override
  String toString() => r'driverLocationControllerProvider';
}

/// Provider qui poll la position du livreur toutes les 10 secondes.
/// Utilisé côté client sur la page détail commande (status EN_ROUTE).

abstract class _$DriverLocationController
    extends $AsyncNotifier<DriverLocation?> {
  late final _$args = ref.$arg as String;
  String get orderId => _$args;

  FutureOr<DriverLocation?> build(String orderId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DriverLocation?>, DriverLocation?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DriverLocation?>, DriverLocation?>,
              AsyncValue<DriverLocation?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
