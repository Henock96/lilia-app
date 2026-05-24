import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../constants/app_constants.dart';
import '../../auth/repository/firebase_auth_repository.dart';

part 'tracking_socket_service.g.dart';

/// Position du livreur reçue via WebSocket.
class DriverPositionEvent {
  final double lat;
  final double lng;
  final int? eta;
  final DateTime timestamp;

  const DriverPositionEvent({
    required this.lat,
    required this.lng,
    this.eta,
    required this.timestamp,
  });

  factory DriverPositionEvent.fromJson(Map<String, dynamic> json) {
    return DriverPositionEvent(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      eta: (json['eta'] as num?)?.toInt(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }
}

/// Service Socket.io qui écoute le namespace `/tracking` du backend.
///
/// Events reçus :
///   - `driver:position` { lat, lng, eta, timestamp }  → position GPS du livreur
///   - `order:status`    { status }                    → changement de statut commande
///
/// Pattern : un seul socket réutilisé pour toute la session.
/// Le caller s'abonne à une commande via `watch(orderId)` et reçoit les events
/// dans des streams. Plusieurs watchers peuvent coexister (multi-orderId).
class TrackingSocketService {
  final FirebaseAuthenticationRepository _auth;

  io.Socket? _socket;
  bool _isConnecting = false;

  final _positionStreams = <String, StreamController<DriverPositionEvent>>{};
  final _statusStreams = <String, StreamController<String>>{};
  final _watchedOrders = <String>{};

  TrackingSocketService(this._auth);

  bool get isConnected => _socket?.connected ?? false;

  Future<void> _ensureConnected() async {
    if (isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final token = await _auth.getIdToken();
      if (token == null) {
        debugPrint('[Tracking WS] Pas de token, connexion annulée');
        return;
      }

      _socket?.dispose();
      _socket = io.io(
        '${AppConstants.wsUrl}${AppConstants.trackingNamespace}',
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .disableAutoConnect()
            .build(),
      );

      _socket!
        ..onConnect((_) {
          debugPrint('[Tracking WS] connected');
          // Re-watch toutes les commandes après reconnexion
          for (final orderId in _watchedOrders) {
            _socket!.emit('order:watch', {'orderId': orderId});
          }
        })
        ..onDisconnect((reason) => debugPrint('[Tracking WS] disconnected: $reason'))
        ..onConnectError((e) => debugPrint('[Tracking WS] connect error: $e'))
        ..onError((e) => debugPrint('[Tracking WS] error: $e'))
        ..on('driver:position', (data) {
          if (data is! Map) return;
          try {
            final event = DriverPositionEvent.fromJson(Map<String, dynamic>.from(data));
            // Le payload ne contient pas l'orderId — broadcast à tous les watchers
            // (en pratique le client ne watch qu'une commande à la fois)
            for (final ctrl in _positionStreams.values) {
              if (!ctrl.isClosed) ctrl.add(event);
            }
          } catch (e) {
            debugPrint('[Tracking WS] parse position error: $e');
          }
        })
        ..on('order:status', (data) {
          if (data is! Map) return;
          final status = data['status'] as String?;
          if (status == null) return;
          for (final ctrl in _statusStreams.values) {
            if (!ctrl.isClosed) ctrl.add(status);
          }
        });

      _socket!.connect();
    } catch (e) {
      debugPrint('[Tracking WS] connect threw: $e');
    } finally {
      _isConnecting = false;
    }
  }

  /// S'abonne à une commande. Retourne deux streams (position + statut).
  /// Le caller doit appeler `unwatch(orderId)` quand il n'a plus besoin.
  ({Stream<DriverPositionEvent> position, Stream<String> status}) watch(String orderId) {
    final posCtrl = _positionStreams.putIfAbsent(
      orderId,
      () => StreamController<DriverPositionEvent>.broadcast(),
    );
    final stCtrl = _statusStreams.putIfAbsent(
      orderId,
      () => StreamController<String>.broadcast(),
    );

    _watchedOrders.add(orderId);
    _ensureConnected().then((_) {
      if (isConnected) {
        _socket!.emit('order:watch', {'orderId': orderId});
      }
    });

    return (position: posCtrl.stream, status: stCtrl.stream);
  }

  void unwatch(String orderId) {
    _watchedOrders.remove(orderId);
    _positionStreams.remove(orderId)?.close();
    _statusStreams.remove(orderId)?.close();
  }

  /// Reconnecte avec un nouveau token (après refresh Firebase).
  Future<void> reconnect() async {
    _socket?.dispose();
    _socket = null;
    await _ensureConnected();
  }

  void dispose() {
    for (final c in _positionStreams.values) {
      c.close();
    }
    for (final c in _statusStreams.values) {
      c.close();
    }
    _positionStreams.clear();
    _statusStreams.clear();
    _watchedOrders.clear();
    _socket?.dispose();
    _socket = null;
  }
}

@Riverpod(keepAlive: true)
TrackingSocketService trackingSocketService(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  final service = TrackingSocketService(auth);
  ref.onDispose(() => service.dispose());
  return service;
}
