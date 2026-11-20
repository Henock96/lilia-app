// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reservationRepository)
final reservationRepositoryProvider = ReservationRepositoryProvider._();

final class ReservationRepositoryProvider
    extends
        $FunctionalProvider<
          ReservationRepository,
          ReservationRepository,
          ReservationRepository
        >
    with $Provider<ReservationRepository> {
  ReservationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReservationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReservationRepository create(Ref ref) {
    return reservationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReservationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReservationRepository>(value),
    );
  }
}

String _$reservationRepositoryHash() =>
    r'e41f8f615c6b560555886dcd2388f449108f9ad8';

/// Bornes de réservation d'un restaurant (premier et dernier jour, taille de
/// groupe maximale).

@ProviderFor(reservationBounds)
final reservationBoundsProvider = ReservationBoundsFamily._();

/// Bornes de réservation d'un restaurant (premier et dernier jour, taille de
/// groupe maximale).

final class ReservationBoundsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReservationAvailability>,
          ReservationAvailability,
          FutureOr<ReservationAvailability>
        >
    with
        $FutureModifier<ReservationAvailability>,
        $FutureProvider<ReservationAvailability> {
  /// Bornes de réservation d'un restaurant (premier et dernier jour, taille de
  /// groupe maximale).
  ReservationBoundsProvider._({
    required ReservationBoundsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reservationBoundsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reservationBoundsHash();

  @override
  String toString() {
    return r'reservationBoundsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReservationAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReservationAvailability> create(Ref ref) {
    final argument = this.argument as String;
    return reservationBounds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReservationBoundsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reservationBoundsHash() => r'e11128ca645ab4743d250e1f5f94727ea67df61b';

/// Bornes de réservation d'un restaurant (premier et dernier jour, taille de
/// groupe maximale).

final class ReservationBoundsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReservationAvailability>, String> {
  ReservationBoundsFamily._()
    : super(
        retry: null,
        name: r'reservationBoundsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Bornes de réservation d'un restaurant (premier et dernier jour, taille de
  /// groupe maximale).

  ReservationBoundsProvider call(String restaurantId) =>
      ReservationBoundsProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'reservationBoundsProvider';
}

/// Créneaux libres d'un jour (`AAAA-MM-JJ`) pour un groupe.

@ProviderFor(reservationSlots)
final reservationSlotsProvider = ReservationSlotsFamily._();

/// Créneaux libres d'un jour (`AAAA-MM-JJ`) pour un groupe.

final class ReservationSlotsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReservationAvailability>,
          ReservationAvailability,
          FutureOr<ReservationAvailability>
        >
    with
        $FutureModifier<ReservationAvailability>,
        $FutureProvider<ReservationAvailability> {
  /// Créneaux libres d'un jour (`AAAA-MM-JJ`) pour un groupe.
  ReservationSlotsProvider._({
    required ReservationSlotsFamily super.from,
    required (String, String, int) super.argument,
  }) : super(
         retry: null,
         name: r'reservationSlotsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reservationSlotsHash();

  @override
  String toString() {
    return r'reservationSlotsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ReservationAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReservationAvailability> create(Ref ref) {
    final argument = this.argument as (String, String, int);
    return reservationSlots(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is ReservationSlotsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reservationSlotsHash() => r'9643bd8dac321484d0527d2e94962391d6b33005';

/// Créneaux libres d'un jour (`AAAA-MM-JJ`) pour un groupe.

final class ReservationSlotsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ReservationAvailability>,
          (String, String, int)
        > {
  ReservationSlotsFamily._()
    : super(
        retry: null,
        name: r'reservationSlotsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Créneaux libres d'un jour (`AAAA-MM-JJ`) pour un groupe.

  ReservationSlotsProvider call(
    String restaurantId,
    String date,
    int partySize,
  ) => ReservationSlotsProvider._(
    argument: (restaurantId, date, partySize),
    from: this,
  );

  @override
  String toString() => r'reservationSlotsProvider';
}

/// « Mes réservations ». Rafraîchi par les push `reservation_update`.

@ProviderFor(myReservations)
final myReservationsProvider = MyReservationsProvider._();

/// « Mes réservations ». Rafraîchi par les push `reservation_update`.

final class MyReservationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClientReservation>>,
          List<ClientReservation>,
          FutureOr<List<ClientReservation>>
        >
    with
        $FutureModifier<List<ClientReservation>>,
        $FutureProvider<List<ClientReservation>> {
  /// « Mes réservations ». Rafraîchi par les push `reservation_update`.
  MyReservationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myReservationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myReservationsHash();

  @$internal
  @override
  $FutureProviderElement<List<ClientReservation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClientReservation>> create(Ref ref) {
    return myReservations(ref);
  }
}

String _$myReservationsHash() => r'cbf81c2961de401b2d82ac91ff0c5d423ad552e9';

@ProviderFor(clientReservation)
final clientReservationProvider = ClientReservationFamily._();

final class ClientReservationProvider
    extends
        $FunctionalProvider<
          AsyncValue<ClientReservation>,
          ClientReservation,
          FutureOr<ClientReservation>
        >
    with
        $FutureModifier<ClientReservation>,
        $FutureProvider<ClientReservation> {
  ClientReservationProvider._({
    required ClientReservationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'clientReservationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$clientReservationHash();

  @override
  String toString() {
    return r'clientReservationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ClientReservation> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ClientReservation> create(Ref ref) {
    final argument = this.argument as String;
    return clientReservation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ClientReservationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$clientReservationHash() => r'93568d9242c4bf080b8164d84f78e06e7a63eb90';

final class ClientReservationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ClientReservation>, String> {
  ClientReservationFamily._()
    : super(
        retry: null,
        name: r'clientReservationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ClientReservationProvider call(String id) =>
      ClientReservationProvider._(argument: id, from: this);

  @override
  String toString() => r'clientReservationProvider';
}
