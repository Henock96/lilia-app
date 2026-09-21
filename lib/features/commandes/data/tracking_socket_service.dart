import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../constants/app_constants.dart';
import '../../auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/core/log.dart';

part 'tracking_socket_service.g.dart';

/// Position du livreur reçue via WebSocket.
class DriverPositionEvent {
  final String? orderId;
  final double lat;
  final double lng;
  final int? eta;
  final DateTime timestamp;

  const DriverPositionEvent({
    this.orderId,
    required this.lat,
    required this.lng,
    this.eta,
    required this.timestamp,
  });

  factory DriverPositionEvent.fromJson(Map<String, dynamic> json) {
    return DriverPositionEvent(
      orderId: json['orderId'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      eta: (json['eta'] as num?)?.toInt(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['timestamp'] as num).toInt(),
            )
          : DateTime.now(),
    );
  }
}

/// Service Socket.io qui écoute le namespace `/tracking` du backend.
///
/// Events reçus :
///   - `driver:position` { orderId?, lat, lng, eta, timestamp } → position GPS du livreur
///   - `order:status`    { orderId?, status }                  → changement de statut commande
///
/// Pattern : un seul socket réutilisé pour toute la session.
/// Le caller s'abonne à une commande via `watch(orderId)` et reçoit les events
/// dans des streams. Plusieurs watchers peuvent coexister (multi-orderId).
/// Fabrique la connexion. Un point d'injection, et un seul.
///
/// Sans lui, `TrackingSocketService` ouvre un vrai socket vers
/// `lilia-backend.onrender.com` dès qu'on l'exerce : le cycle de vie de la
/// connexion — précisément ce qui était cassé — n'était donc vérifiable
/// qu'à la main, appareil en main, en regardant la consommation de données.
typedef SocketFactory = io.Socket Function(String url, dynamic options);

io.Socket _socketReel(String url, dynamic options) => io.io(url, options);

class TrackingSocketService {
  final FirebaseAuthenticationRepository _auth;
  final SocketFactory _fabrique;

  io.Socket? _socket;
  bool _isConnecting = false;

  final _positionStreams = <String, StreamController<DriverPositionEvent>>{};
  final _statusStreams = <String, StreamController<String>>{};
  final _watchedOrders = <String>{};

  TrackingSocketService(this._auth, {SocketFactory? fabrique})
      : _fabrique = fabrique ?? _socketReel;

  bool get isConnected => _socket?.connected ?? false;

  /// Une connexion est-elle ouverte ? Distinct d'[isConnected], qui interroge
  /// l'état du transport : ici on demande si le socket **existe**, ce qui est
  /// la question du cycle de vie.
  @visibleForTesting
  bool get socketOuvert => _socket != null;

  Future<void> _ensureConnected() async {
    // ⚠️ `_isConnecting` mentait, et c'est le correctif.
    //
    // Il était relâché dans un `finally` posé juste après `connect()` —
    // c'est-à-dire **avant** que la poignée de main ait abouti. Or
    // `isConnected` interroge `_socket?.connected`, qui reste `false` pendant
    // tout ce temps. Entre les deux, un second `watch()` passait les deux
    // gardes, faisait `_socket?.dispose()` sur la connexion en cours
    // d'ouverture, et en créait une seconde.
    //
    // Le défaut s'auto-réparait — `onConnect` réémet `order:watch` pour
    // toutes les commandes suivies — au prix d'un socket jeté et d'un délai
    // de plus avant la première position, sur un réseau où chaque
    // aller-retour se paie.
    //
    // Le drapeau est désormais relâché par les rappels du transport
    // (`onConnect`, `onConnectError`), pas par la fin de la fonction. Il
    // décrit donc ce qu'il prétend décrire : une connexion en cours.
    //
    // ⚠️ Ne PAS ajouter `_socket != null` à cette garde : après dix
    // tentatives infructueuses, socket.io laisse un socket vivant et
    // déconnecté, et c'est précisément le cas où il faut en refaire un.
    if (isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final token = await _auth.getIdToken();
      if (token == null) {
        logDebug('[Tracking WS] Pas de token, connexion annulée');
        _isConnecting = false;
        return;
      }

      _socket?.dispose();
      _socket = _fabrique(
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
          logDebug('[Tracking WS] connected');
          _isConnecting = false;
          // Re-watch toutes les commandes après reconnexion
          for (final orderId in _watchedOrders) {
            _socket!.emit('order:watch', {'orderId': orderId});
          }
        })
        ..onDisconnect(
          (reason) => logDebug('[Tracking WS] disconnected: $reason'),
        )
        ..onConnectError((e) {
          // Socket.io rejouera lui-même (10 tentatives, backoff 2 s → 10 s).
          // Le drapeau retombe pour qu'un `watch()` ultérieur puisse repartir
          // d'un socket neuf si celui-ci finit par abandonner.
          _isConnecting = false;
          logDebug('[Tracking WS] connect error: $e');
        })
        ..onError((e) => logDebug('[Tracking WS] error: $e'))
        ..on('driver:position', (data) {
          if (data is! Map) return;
          try {
            final event = DriverPositionEvent.fromJson(
              Map<String, dynamic>.from(data),
            );
            // Si le backend fournit l'orderId, router uniquement vers le watcher correspondant
            if (event.orderId != null &&
                _positionStreams.containsKey(event.orderId)) {
              final ctrl = _positionStreams[event.orderId];
              if (ctrl != null && !ctrl.isClosed) ctrl.add(event);
            } else {
              // Repli rétrocompatible si orderId est omis par le serveur
              for (final ctrl in _positionStreams.values) {
                if (!ctrl.isClosed) ctrl.add(event);
              }
            }
          } catch (e) {
            logDebug('[Tracking WS] parse position error: $e');
          }
        })
        ..on('order:status', (data) {
          if (data is! Map) return;
          final status = data['status'] as String?;
          final orderId = data['orderId'] as String?;
          if (status == null) return;

          // Si le backend fournit l'orderId, router uniquement vers le watcher correspondant
          if (orderId != null && _statusStreams.containsKey(orderId)) {
            final ctrl = _statusStreams[orderId];
            if (ctrl != null && !ctrl.isClosed) ctrl.add(status);
          } else {
            // Repli rétrocompatible si orderId est omis par le serveur
            for (final ctrl in _statusStreams.values) {
              if (!ctrl.isClosed) ctrl.add(status);
            }
          }
        });

      _socket!.connect();
    } catch (e) {
      // Échec avant même d'avoir un socket : rien n'est en cours.
      _isConnecting = false;
      logDebug('[Tracking WS] connect threw: $e');
    }
  }

  /// S'abonne à une commande. Retourne deux streams (position + statut).
  /// Le caller doit appeler `unwatch(orderId)` quand il n'a plus besoin.
  ({Stream<DriverPositionEvent> position, Stream<String> status}) watch(
    String orderId,
  ) {
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

    // ⚠️ Le socket était laissé **ouvert pour la vie de l'application**.
    //
    // Ce service est `keepAlive` et n'était disposé qu'avec le conteneur :
    // `unwatch` retirait la commande de la liste, mais personne ne fermait la
    // connexion. Consulter une commande en cours puis revenir à l'accueil
    // laissait donc un WebSocket actif, avec sa reconnexion automatique
    // (10 tentatives, backoff 2 s → 10 s) — de la batterie et de la data, en
    // continu, pour une course que plus aucun écran ne regarde.
    //
    // `_ensureConnected()` le rouvrira au prochain `watch`. Le service savait
    // déjà répondre à la question (`isWatching`) ; il ne s'en servait que
    // pour éviter une reconnexion inutile, jamais pour fermer.
    if (_watchedOrders.isEmpty) _fermerSocket();
  }

  /// Ferme la connexion sans toucher aux flux : ils appartiennent aux
  /// commandes suivies, et il n'y en a plus.
  void _fermerSocket() {
    _isConnecting = false;
    if (_socket == null) return;
    logDebug('[Tracking WS] plus aucune commande suivie — fermeture');
    _socket?.dispose();
    _socket = null;
  }

  /// Au moins une commande est actuellement suivie (socket utile).
  bool get isWatching => _watchedOrders.isNotEmpty;

  /// Reconnecte avec un nouveau token (après refresh Firebase).
  /// No-op s'il n'y a aucune commande suivie : inutile d'ouvrir un socket.
  Future<void> reconnect() async {
    if (_watchedOrders.isEmpty) return;
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
    _fermerSocket();
  }
}

@Riverpod(keepAlive: true)
TrackingSocketService trackingSocketService(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  final service = TrackingSocketService(auth);

  // C3 : le token Firebase est capturé une seule fois à l'ouverture du socket.
  // Firebase le rafraîchit (~1h) via `idTokenChanges()` ; sans ré-injection, le
  // backend finit par rejeter le socket sur token expiré. On reconnecte donc
  // avec le nouveau token dès qu'il change — uniquement si une commande est
  // suivie (le getter `isWatching` + le garde dans `reconnect()` évitent
  // d'ouvrir un socket inutile au login/logout).
  ref.listen(firebaseIdTokenProvider, (previous, next) {
    final token = next.value;
    if (token == null) {
      // Déconnexion ou changement de compte : le socket était authentifié par
      // le jeton du compte parti. Le laisser ouvert, c'est laisser un canal
      // temps réel rattaché à quelqu'un qui n'est plus là.
      service.dispose();
      return;
    }
    if (service.isWatching) service.reconnect();
  });

  ref.onDispose(() => service.dispose());
  return service;
}
