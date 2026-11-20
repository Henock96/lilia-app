import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/reservations/data/reservation_repository.dart';

part 'reservation_providers.g.dart';

@Riverpod(keepAlive: true)
ReservationRepository reservationRepository(Ref ref) =>
    ReservationRepository(ref.read(apiClientProvider));

/// Bornes de réservation d'un restaurant (premier et dernier jour, taille de
/// groupe maximale).
@riverpod
Future<ReservationAvailability> reservationBounds(
  Ref ref,
  String restaurantId,
) => ref.read(reservationRepositoryProvider).availability(restaurantId);

/// Créneaux libres d'un jour (`AAAA-MM-JJ`) pour un groupe.
@riverpod
Future<ReservationAvailability> reservationSlots(
  Ref ref,
  String restaurantId,
  String date,
  int partySize,
) => ref
    .read(reservationRepositoryProvider)
    .availability(restaurantId, date: date, partySize: partySize);

/// « Mes réservations ». Rafraîchi par les push `reservation_update`.
@riverpod
Future<List<ClientReservation>> myReservations(Ref ref) =>
    ref.read(reservationRepositoryProvider).mine();

@riverpod
Future<ClientReservation> clientReservation(Ref ref, String id) =>
    ref.read(reservationRepositoryProvider).get(id);
