import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/reservations/data/reservation_repository.dart';
import 'package:lilia_app/models/restaurant.dart';

/// Contrat app client ↔ backend (Lot 4, 4D), sur des réponses RÉELLES.
///
/// Les fixtures ont été produites par le serveur : harnais HTTP du backend
/// (`test/http/reservations.http-spec.ts`), option `HTTP_DUMP_DIR`, parcours
/// complet (disponibilités → demande → acceptation → paiement → code →
/// honorée). À régénérer quand le contrat évolue.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(
          File(
            'test/features/reservations/fixtures/$name.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

ApiClient _client() => ApiClient.test(
  baseUrl: 'https://test.local',
  tokenProvider: () async => 'tok',
  forceRefreshToken: () async => 'tok2',
);

void main() {
  test('fiche vendeur : reservable lu du serveur, faux s’il est absent', () {
    final raw = _fixture('client_vendor_detail_reservable');
    final data = raw['data'] as Map<String, dynamic>;
    expect(data['reservable'], isTrue);
    expect(Restaurant.fromJson(data).reservable, isTrue);
    expect(
      Restaurant.fromJson({...data}..remove('reservable')).reservable,
      isFalse,
    );
  });

  test('disponibilités : bornes puis créneaux du jour', () async {
    final client = _client();
    DioAdapter(dio: client.dio)
      ..onGet(
        '/vendors/v1/reservation-availability',
        (s) => s.reply(200, _fixture('client_availability_bounds')),
        queryParameters: <String, dynamic>{},
      )
      ..onGet(
        '/vendors/v1/reservation-availability',
        (s) => s.reply(200, _fixture('client_availability_slots')),
        queryParameters: {'date': '2026-11-21', 'partySize': '2'},
      );
    final repo = ReservationRepository(client);

    final bounds = await repo.availability('v1');
    expect(bounds.firstDate, '2026-11-20');
    expect(bounds.lastDate, '2026-12-20');
    expect(bounds.maxPartySize, 8);
    expect(bounds.slots, isEmpty);

    final day = await repo.availability(
      'v1',
      date: '2026-11-21',
      partySize: 2,
    );
    expect(day.date, '2026-11-21');
    expect(day.slots.first.time, '11:00');
    expect(day.slots.first.arrivalAt, DateTime.utc(2026, 11, 21, 10));
  });

  test('demande : en-tête Idempotency-Key, réservation en attente', () async {
    final client = _client();
    Object? sentKey;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sentKey = o.headers['Idempotency-Key'];
          h.next(o);
        },
      ),
    );
    DioAdapter(dio: client.dio).onPost(
      '/reservations',
      (s) => s.reply(201, _fixture('client_create_pending')),
      data: {
        'restaurantId': 'v1',
        'date': '2026-11-21',
        'time': '11:00',
        'partySize': 2,
      },
    );

    final r = await ReservationRepository(client).create(
      restaurantId: 'v1',
      date: '2026-11-21',
      time: '11:00',
      partySize: 2,
      idempotencyKey: 'k-1',
    );
    expect(sentKey, 'k-1');
    expect(r.status, 'PENDING');
    expect(r.payment, isNull);
    expect(r.items.single.name, 'Poulet DG');
    expect(r.allowedActions, ['cancel']);
  });

  test('acceptée : à payer, commande liée, politique d’annulation', () async {
    final client = _client();
    final raw = _fixture('client_get_awaiting_payment');
    final d = raw['data'] as Map<String, dynamic>;
    DioAdapter(
      dio: client.dio,
    ).onGet('/reservations/${d['id']}', (s) => s.reply(200, raw));

    final r = await ReservationRepository(client).get(d['id'] as String);
    final p = d['payment'] as Map<String, dynamic>;
    expect(r.status, 'AWAITING_PAYMENT');
    expect(r.canPay, isTrue);
    expect(r.canCancel, isTrue);
    expect(r.payment!.orderId, p['orderId']);
    expect(r.payment!.total, p['total']);
    expect(r.spaceLabel, 'Table 1');
    expect(r.restaurantName, (d['restaurant'] as Map)['nom']);
    expect(r.cancellationPolicy!.noShowRefundable, isFalse);
    expect(
      r.cancellationPolicy!.freeUntil,
      DateTime.parse((d['cancellationPolicy'] as Map)['freeUntil'] as String),
    );
    expect(
      r.paymentDeadlineAt,
      DateTime.parse(d['paymentDeadlineAt'] as String),
    );
  });

  test('mes réservations : liste réelle', () async {
    final client = _client();
    DioAdapter(dio: client.dio).onGet(
      '/reservations/me',
      (s) => s.reply(200, _fixture('client_list_me_confirmed')),
      queryParameters: {'page': '1', 'limit': '50'},
    );
    final list = await ReservationRepository(client).mine();
    expect(list.single.status, 'CONFIRMED');
    expect(list.single.isActive, isTrue);
  });

  test('honorée : plus aucun geste', () async {
    final client = _client();
    final raw = _fixture('client_get_honored');
    final d = raw['data'] as Map<String, dynamic>;
    DioAdapter(
      dio: client.dio,
    ).onGet('/reservations/${d['id']}', (s) => s.reply(200, raw));
    final r = await ReservationRepository(client).get(d['id'] as String);
    expect(r.status, 'HONORED');
    expect(r.allowedActions, isEmpty);
    expect(r.isActive, isFalse);
  });

  test('commande liée prête : code servi au client, aucun geste (D-2)', () {
    final d =
        _fixture('client_linked_order_ready')['data'] as Map<String, dynamic>;
    expect(d['status'], 'PRET');
    expect(d['reservationId'], isA<String>());
    expect(d['pickupCode'], matches(RegExp(r'^\d{4}$')));
    expect(d['allowedActions'], isEmpty);
  });

  test('geste inconnu du serveur : ignoré', () {
    final r = ClientReservation.fromJson({
      'id': 'r',
      'status': 'PENDING',
      'allowedActions': ['cancel', 'teleport'],
    });
    expect(r.allowedActions, ['cancel']);
  });

  test('clé d’idempotence : UUID v4, différente à chaque demande', () {
    final a = newReservationKey();
    expect(
      a,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(newReservationKey(), isNot(a));
  });
}
