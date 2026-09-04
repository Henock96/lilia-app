import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

/// Service pour gérer la connectivité internet
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isConnected = true;

  ConnectivityService() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Stream<bool> get connectionStream => _controller.stream;
  bool get isConnected => _isConnected;

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la connectivité: $e');
      _isConnected = true; // Par défaut, on suppose qu'on est connecté
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // On est connecté si au moins une connexion est active (WiFi, mobile, etc.)
    _isConnected = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn,
    );

    debugPrint(
      '📡 État de connexion: ${_isConnected ? "Connecté" : "Déconnecté"}',
    );
    if (!_controller.isClosed) {
      _controller.add(_isConnected);
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      return _isConnected;
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la connectivité: $e');
      return true; // En cas d'erreur, on suppose qu'on est connecté
    }
  }

  void dispose() {
    _controller.close();
  }
}

@riverpod
ConnectivityService connectivityService(Ref ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
}

@riverpod
Stream<bool> connectivityStatus(Ref ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectionStream;
}

@riverpod
Future<bool> isConnected(Ref ref) async {
  final service = ref.watch(connectivityServiceProvider);
  return service.checkConnectivity();
}
