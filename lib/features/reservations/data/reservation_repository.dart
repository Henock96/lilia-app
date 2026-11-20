import 'dart:math';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';

/// Lot 4 (4D) — réservations de table, côté client.
///
/// Disponibilités publiques, demande (précommande = **panier serveur** du
/// client, vidé par le serveur à l'envoi), suivi, annulation. Le paiement
/// passe par la commande liée et l'écran de paiement existant.
///
/// Le serveur décide de tout et publie, sur chaque réservation, les gestes
/// qu'il acceptera (`allowedActions` : `pay`, `cancel`) : l'app les affiche,
/// elle ne recopie jamais la machine d'états (règle 2).
class ReservationRepository {
  ReservationRepository(this._api);

  final ApiClient _api;

  /// Bornes seules (sans [date]) ou créneaux d'un jour.
  Future<ReservationAvailability> availability(
    String restaurantId, {
    String? date,
    int? partySize,
  }) async {
    final res = await _api.getJson(
      '/vendors/$restaurantId/reservation-availability',
      query: {'date': ?date, 'partySize': ?partySize?.toString()},
    );
    return ReservationAvailability.fromJson(ApiResponse.mapOf(res.data));
  }

  /// Envoie la demande. [idempotencyKey] : la même pour les nouvelles
  /// tentatives d'un même envoi (réseau coupé, double tap) — le serveur rend
  /// alors la même réservation au lieu d'en créer une seconde.
  Future<ClientReservation> create({
    required String restaurantId,
    required String date,
    required String time,
    required int partySize,
    required String idempotencyKey,
    String? contactPhone,
    String? note,
  }) async {
    final res = await _api.postJson(
      '/reservations',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'restaurantId': restaurantId,
        'date': date,
        'time': time,
        'partySize': partySize,
        'contactPhone': ?contactPhone,
        'note': ?note,
      },
    );
    return ClientReservation.fromJson(ApiResponse.mapOf(res.data));
  }

  Future<List<ClientReservation>> mine() async {
    final res = await _api.getJson(
      '/reservations/me',
      query: {'page': '1', 'limit': '50'},
    );
    return ApiResponse.listOf(res.data)
        .whereType<Map<String, dynamic>>()
        .map(ClientReservation.fromJson)
        .toList(growable: false);
  }

  Future<ClientReservation> get(String id) async {
    final res = await _api.getJson('/reservations/$id');
    return ClientReservation.fromJson(ApiResponse.mapOf(res.data));
  }

  Future<ClientReservation> cancel(String id) async {
    final res = await _api.postJson('/reservations/$id/cancel', body: {});
    return ClientReservation.fromJson(ApiResponse.mapOf(res.data));
  }
}

/// Clé d'idempotence (UUID v4) d'une demande.
String newReservationKey() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Codes d'erreur serveur (`error.code`) que les écrans distinguent.
abstract final class ReservationErrorCodes {
  static const notBookable = 'RESERVATION_NOT_BOOKABLE';
  static const slotUnavailable = 'RESERVATION_SLOT_UNAVAILABLE';
  static const capacityTaken = 'RESERVATION_CAPACITY_TAKEN';
  static const cartEmpty = 'RESERVATION_CART_EMPTY';
  static const cartOtherVendor = 'RESERVATION_CART_OTHER_VENDOR';
  static const cartChanged = 'RESERVATION_CART_CHANGED';
  static const phoneRequired = 'RESERVATION_PHONE_REQUIRED';
  static const stateConflict = 'RESERVATION_STATE_CONFLICT';
  static const paymentInProgress = 'RESERVATION_PAYMENT_IN_PROGRESS';
}

/// Statut du point de vue du client.
String clientReservationStatusLabel(String status) => switch (status) {
  'PENDING' => 'En attente du restaurant',
  'AWAITING_PAYMENT' => 'Acceptée — à payer',
  'CONFIRMED' => 'Confirmée',
  'DECLINED' => 'Refusée par le restaurant',
  'EXPIRED' => 'Expirée',
  'CANCELLED_BY_CLIENT' => 'Annulée',
  'CANCELLED_BY_VENDOR' => 'Annulée par le restaurant',
  'HONORED' => 'Honorée',
  'NO_SHOW' => 'Absence constatée',
  _ => status,
};

/// Motif de refus ou d'annulation, tel que le client le lit.
String clientReservationReasonLabel(String reason) => switch (reason) {
  'FULLY_BOOKED' => 'Le restaurant est complet à cette heure.',
  'CLOSED' || 'CLOSED_UNEXPECTEDLY' => 'Le restaurant est fermé.',
  'ITEMS_UNAVAILABLE' => 'Des plats de votre précommande ne sont plus servis.',
  'PARTY_TOO_LARGE' => 'Le groupe est trop nombreux pour le restaurant.',
  'OVERBOOKED' => 'Le restaurant a trop de réservations.',
  'CLIENT_REQUEST' => 'Annulée à votre demande.',
  _ => 'Le restaurant n’a pas précisé de motif.',
};

int _i(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
int? _iOrNull(Object? v) => v is num ? v.toInt() : null;
String _s(Object? v) => v is String ? v : '';
String? _sOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

/// Instant UTC du serveur ; l'affichage se fait à l'heure de Brazzaville.
DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;
Map<String, dynamic> _m(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};
List<Map<String, dynamic>> _l(Object? v) => v is List
    ? v.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

class ReservationSlot {
  const ReservationSlot({required this.time, required this.arrivalAt});

  factory ReservationSlot.fromJson(Map<String, dynamic> j) => ReservationSlot(
    time: _s(j['time']),
    arrivalAt: _d(j['arrivalAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Heure locale de Brazzaville (`HH:mm`), renvoyée telle quelle à la demande.
  final String time;
  final DateTime arrivalAt;
}

/// Bornes de réservation du restaurant, et créneaux d'un jour s'il a été
/// demandé (`date`).
class ReservationAvailability {
  const ReservationAvailability({
    required this.maxPartySize,
    required this.firstDate,
    required this.lastDate,
    this.date,
    this.slots = const [],
  });

  factory ReservationAvailability.fromJson(Map<String, dynamic> j) =>
      ReservationAvailability(
        maxPartySize: _i(j['maxPartySize'], 1),
        firstDate: _s(j['firstDate']),
        lastDate: _s(j['lastDate']),
        date: _sOrNull(j['date']),
        slots: _l(j['slots']).map(ReservationSlot.fromJson).toList(),
      );

  final int maxPartySize;

  /// Jours civils de Brazzaville (`AAAA-MM-JJ`).
  final String firstDate;
  final String lastDate;
  final String? date;
  final List<ReservationSlot> slots;
}

class ClientReservationItem {
  const ClientReservationItem({
    required this.name,
    required this.quantity,
    this.variantLabel,
    this.options = const [],
  });

  factory ClientReservationItem.fromJson(Map<String, dynamic> j) =>
      ClientReservationItem(
        name: _sOrNull(j['menuName']) ?? _s(j['productName']),
        quantity: _i(j['quantite'], 1),
        variantLabel: _sOrNull(j['variantLabel']),
        options: [for (final o in _l(j['options'])) ?_sOrNull(o['optionName'])],
      );

  final String name;
  final int quantity;
  final String? variantLabel;
  final List<String> options;
}

/// Commande liée, créée quand le restaurant accepte. Montants en XAF entiers.
class ClientReservationPayment {
  const ClientReservationPayment({
    required this.orderId,
    required this.orderStatus,
    required this.subTotal,
    required this.serviceFee,
    required this.total,
    required this.priceChanged,
    this.indicativeSubTotal,
  });

  factory ClientReservationPayment.fromJson(Map<String, dynamic> j) =>
      ClientReservationPayment(
        orderId: _s(j['orderId']),
        orderStatus: _s(j['orderStatus']),
        subTotal: _i(j['subTotal']),
        serviceFee: _i(j['serviceFee']),
        total: _i(j['total']),
        indicativeSubTotal: _iOrNull(j['indicativeSubTotal']),
        priceChanged: j['priceChanged'] == true,
      );

  final String orderId;
  final String orderStatus;
  final int subTotal;
  final int serviceFee;
  final int total;
  final int? indicativeSubTotal;
  final bool priceChanged;
}

/// Politique d'annulation servie par le serveur (présente une fois acceptée).
class CancellationPolicy {
  const CancellationPolicy({
    required this.freeUntil,
    required this.refundable,
    required this.noShowRefundable,
  });

  factory CancellationPolicy.fromJson(Map<String, dynamic> j) =>
      CancellationPolicy(
        freeUntil: _d(j['freeUntil']),
        refundable: j['refundable'] == true,
        noShowRefundable: j['noShowRefundable'] == true,
      );

  final DateTime? freeUntil;
  final bool refundable;
  final bool noShowRefundable;
}

/// Une réservation telle que le client la voit (`toClientView`).
class ClientReservation {
  const ClientReservation({
    required this.id,
    required this.status,
    required this.restaurantId,
    required this.restaurantName,
    required this.partySize,
    required this.arrivalAt,
    required this.spaceLabel,
    required this.items,
    required this.allowedActions,
    this.endsAt,
    this.note,
    this.declineReason,
    this.cancelReason,
    this.payment,
    this.cancellationPolicy,
    this.responseDeadlineAt,
    this.paymentDeadlineAt,
  });

  factory ClientReservation.fromJson(Map<String, dynamic> j) {
    final restaurant = _m(j['restaurant']);
    final payment = j['payment'];
    final policy = j['cancellationPolicy'];
    return ClientReservation(
      id: _s(j['id']),
      status: _s(j['status']),
      restaurantId: _s(restaurant['id']),
      restaurantName: _s(restaurant['nom']),
      partySize: _i(j['partySize'], 1),
      arrivalAt: _d(j['arrivalAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: _d(j['endsAt']),
      spaceLabel: _s(j['spaceLabel']),
      note: _sOrNull(j['note']),
      declineReason: _sOrNull(j['declineReason']),
      cancelReason: _sOrNull(j['cancelReason']),
      items: _l(j['items']).map(ClientReservationItem.fromJson).toList(),
      payment: payment is Map<String, dynamic>
          ? ClientReservationPayment.fromJson(payment)
          : null,
      cancellationPolicy: policy is Map<String, dynamic>
          ? CancellationPolicy.fromJson(policy)
          : null,
      responseDeadlineAt: _d(j['responseDeadlineAt']),
      paymentDeadlineAt: _d(j['paymentDeadlineAt']),
      allowedActions: [
        if (j['allowedActions'] case final List<dynamic> list)
          for (final a in list)
            if (a == 'pay' || a == 'cancel') a as String,
      ],
    );
  }

  final String id;
  final String status;
  final String restaurantId;
  final String restaurantName;
  final int partySize;
  final DateTime arrivalAt;
  final DateTime? endsAt;
  final String spaceLabel;
  final String? note;
  final String? declineReason;
  final String? cancelReason;
  final List<ClientReservationItem> items;
  final ClientReservationPayment? payment;
  final CancellationPolicy? cancellationPolicy;
  final DateTime? responseDeadlineAt;
  final DateTime? paymentDeadlineAt;

  /// `pay`, `cancel` — vocabulaire fermé, valeur inconnue ignorée.
  final List<String> allowedActions;

  bool get canPay => allowedActions.contains('pay');
  bool get canCancel => allowedActions.contains('cancel');

  /// Réservation encore à venir (affichée en tête de « Mes réservations »).
  bool get isActive =>
      status == 'PENDING' ||
      status == 'AWAITING_PAYMENT' ||
      status == 'CONFIRMED';
}
