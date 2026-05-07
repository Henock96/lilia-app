import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../constants/app_constants.dart';
import '../../../features/auth/repository/firebase_auth_repository.dart';

part 'delivery_tracking_repository.g.dart';

class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;
  final String? driverNom;
  final String? driverPhone;

  const DriverLocation({
    required this.latitude,
    required this.longitude,
    this.updatedAt,
    this.driverNom,
    this.driverPhone,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    final deliverer = json['deliverer'] as Map<String, dynamic>?;
    return DriverLocation(
      latitude: (json['lastLatitude'] as num).toDouble(),
      longitude: (json['lastLongitude'] as num).toDouble(),
      updatedAt: json['lastPositionAt'] != null ? DateTime.parse(json['lastPositionAt'] as String) : null,
      driverNom: deliverer?['nom'] as String?,
      driverPhone: deliverer?['phone'] as String?,
    );
  }
}

/// Récupère la position du livreur pour une commande.
/// Retourne null si la livraison n'a pas encore de position GPS.
Future<DriverLocation?> fetchDriverLocation(String orderId, String token) async {
  final response = await http.get(
    Uri.parse('${AppConstants.baseUrl}/deliveries/by-order/$orderId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode == 200) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final data = body['data'] as Map<String, dynamic>;
    if (data['lastLatitude'] == null) return null;
    return DriverLocation.fromJson(data);
  }
  return null;
}

/// Provider qui poll la position du livreur toutes les 10 secondes.
/// Utilisé côté client sur la page détail commande (status EN_ROUTE).
@riverpod
class DriverLocationController extends _$DriverLocationController {
  Timer? _timer;

  @override
  FutureOr<DriverLocation?> build(String orderId) async {
    ref.onDispose(() => _timer?.cancel());
    _startPolling(orderId);
    return _fetch(orderId);
  }

  Future<DriverLocation?> _fetch(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) return null;
    return fetchDriverLocation(orderId, token);
  }

  void _startPolling(String orderId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!ref.mounted) return;
      final result = await AsyncValue.guard(() => _fetch(orderId));
      if (!ref.mounted) return;
      state = result;
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(orderId));
  }
}
