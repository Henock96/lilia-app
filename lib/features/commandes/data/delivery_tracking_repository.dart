import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../constants/app_constants.dart';
import '../../../features/auth/repository/firebase_auth_repository.dart';
import 'tracking_socket_service.dart';

part 'delivery_tracking_repository.g.dart';

/// Position du livreur affichée à l'utilisateur (côté UI).
/// Construite soit depuis le WebSocket (`DriverPositionEvent`) soit depuis
/// l'endpoint HTTP `GET /deliveries/by-order/:orderId` (fallback initial).
class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;
  final String? driverNom;
  final String? driverPhone;
  final int? etaMinutes;

  const DriverLocation({
    required this.latitude,
    required this.longitude,
    this.updatedAt,
    this.driverNom,
    this.driverPhone,
    this.etaMinutes,
  });

  factory DriverLocation.fromHttpJson(Map<String, dynamic> json) {
    final deliverer = json['deliverer'] as Map<String, dynamic>?;
    return DriverLocation(
      latitude: (json['lastLatitude'] as num).toDouble(),
      longitude: (json['lastLongitude'] as num).toDouble(),
      updatedAt: json['lastPositionAt'] != null
          ? DateTime.parse(json['lastPositionAt'] as String)
          : null,
      driverNom: deliverer?['nom'] as String?,
      driverPhone: deliverer?['phone'] as String?,
    );
  }

  DriverLocation copyWithWsPosition(DriverPositionEvent event) {
    return DriverLocation(
      latitude: event.lat,
      longitude: event.lng,
      updatedAt: event.timestamp,
      driverNom: driverNom,
      driverPhone: driverPhone,
      etaMinutes: event.eta,
    );
  }
}

/// Charge la position initiale via HTTP (et récupère les infos du livreur).
Future<DriverLocation?> fetchDriverLocation(String orderId, String token) async {
  final response = await http.get(
    Uri.parse('${AppConstants.baseUrl}/deliveries/by-order/$orderId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode == 200) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final data = body['data'] as Map<String, dynamic>;
    if (data['lastLatitude'] == null) return null;
    return DriverLocation.fromHttpJson(data);
  }
  return null;
}

/// Controller qui combine WebSocket temps réel + HTTP initial.
///
/// Stratégie :
///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)
@riverpod
class DriverLocationController extends _$DriverLocationController {
  Timer? _httpFallbackTimer;
  StreamSubscription<DriverPositionEvent>? _wsPositionSub;
  StreamSubscription<String>? _wsStatusSub;
  String? _orderId;

  @override
  FutureOr<DriverLocation?> build(String orderId) async {
    _orderId = orderId;
    ref.onDispose(_cleanup);

    final initial = await _fetchHttp(orderId);

    // Abonnement WebSocket
    final socket = ref.read(trackingSocketServiceProvider);
    final streams = socket.watch(orderId);

    DriverLocation? current = initial;

    _wsPositionSub = streams.position.listen((event) {
      if (!ref.mounted) return;
      current = current?.copyWithWsPosition(event) ??
          DriverLocation(
            latitude: event.lat,
            longitude: event.lng,
            updatedAt: event.timestamp,
            etaMinutes: event.eta,
          );
      state = AsyncValue.data(current);
    });

    _wsStatusSub = streams.status.listen((status) {
      debugPrint('[Tracking] order:status → $status');
      // L'UI listen aussi via FCM ; ici on pourrait refresh userOrdersProvider.
    });

    // Fallback HTTP plus rare — la WS prend le relai en temps normal
    _startHttpFallback(orderId);

    return initial;
  }

  Future<DriverLocation?> _fetchHttp(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) return null;
    return fetchDriverLocation(orderId, token);
  }

  void _startHttpFallback(String orderId) {
    _httpFallbackTimer?.cancel();
    _httpFallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!ref.mounted) return;
      try {
        final fresh = await _fetchHttp(orderId);
        if (!ref.mounted || fresh == null) return;
        final previous = state.value;
        // N'écrase pas la position WS plus récente
        if (previous == null ||
            (fresh.updatedAt != null &&
                (previous.updatedAt == null ||
                    fresh.updatedAt!.isAfter(previous.updatedAt!)))) {
          state = AsyncValue.data(fresh);
        }
      } catch (_) {}
    });
  }

  Future<void> refresh() async {
    if (_orderId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchHttp(_orderId!));
  }

  void _cleanup() {
    _httpFallbackTimer?.cancel();
    _wsPositionSub?.cancel();
    _wsStatusSub?.cancel();
    final id = _orderId;
    if (id != null) {
      ref.read(trackingSocketServiceProvider).unwatch(id);
    }
  }
}
