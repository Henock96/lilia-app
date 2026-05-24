// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_tracking_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller qui combine WebSocket temps réel + HTTP initial.
///
/// Stratégie :
///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)

@ProviderFor(DriverLocationController)
final driverLocationControllerProvider = DriverLocationControllerFamily._();

/// Controller qui combine WebSocket temps réel + HTTP initial.
///
/// Stratégie :
///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)
final class DriverLocationControllerProvider
    extends $AsyncNotifierProvider<DriverLocationController, DriverLocation?> {
  /// Controller qui combine WebSocket temps réel + HTTP initial.
  ///
  /// Stratégie :
  ///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
  ///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
  ///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
  ///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)
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
    r'984dc194f3f3ede9ab43d405674da957ec73a921';

/// Controller qui combine WebSocket temps réel + HTTP initial.
///
/// Stratégie :
///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)

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

  /// Controller qui combine WebSocket temps réel + HTTP initial.
  ///
  /// Stratégie :
  ///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
  ///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
  ///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
  ///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)

  DriverLocationControllerProvider call(String orderId) =>
      DriverLocationControllerProvider._(argument: orderId, from: this);

  @override
  String toString() => r'driverLocationControllerProvider';
}

/// Controller qui combine WebSocket temps réel + HTTP initial.
///
/// Stratégie :
///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)

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
