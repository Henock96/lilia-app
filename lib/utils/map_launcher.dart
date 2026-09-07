import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utilitaire d'ouverture d'itinéraire GPS (Google Maps, Apple Maps, Waze, Web).
///
/// Gère la priorité native Android / iOS et retombe proprement sur l'URL Web
/// Google Maps si aucune application de guidage dédiée n'est installée.
class MapLauncher {
  MapLauncher._();

  /// Ouvre l'itinéraire vers les coordonnées fournies.
  ///
  /// [latitude] et [longitude] : coordonnées exactes de la destination.
  /// [label] : Nom du lieu (ex : Nom du restaurant ou repère).
  /// [address] : Adresse textuelle de la destination pour l'affichage humain.
  static Future<bool> openNavigation({
    required double latitude,
    required double longitude,
    String? label,
    String? address,
  }) async {
    final destinationTitle = label ?? address ?? 'Destination';
    final encodedTitle = Uri.encodeComponent(destinationTitle);

    // 1. Android : Essayer l'intent natif geo: ou google.navigation:
    if (!kIsWeb && Platform.isAndroid) {
      // Priorité à l'intent de guidage direct Google Maps
      final androidNavUri = Uri.parse(
        'google.navigation:q=$latitude,$longitude&mode=d',
      );
      if (await canLaunchUrl(androidNavUri)) {
        try {
          final launched = await launchUrl(
            androidNavUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}
      }

      // Repli 2 : Schéma geo standard
      final geoUri = Uri.parse(
        'geo:$latitude,$longitude?q=$latitude,$longitude($encodedTitle)',
      );
      if (await canLaunchUrl(geoUri)) {
        try {
          final launched = await launchUrl(
            geoUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}
      }
    }

    // 2. iOS : Essayer Google Maps App ou Apple Maps natif
    if (!kIsWeb && Platform.isIOS) {
      // Google Maps app si installée
      final googleMapsAppUri = Uri.parse(
        'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
      );
      if (await canLaunchUrl(googleMapsAppUri)) {
        try {
          final launched = await launchUrl(
            googleMapsAppUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}
      }

      // Apple Maps (pré-installé sur tout appareil iOS)
      final appleMapsUri = Uri.parse(
        'maps://?daddr=$latitude,$longitude&q=$encodedTitle',
      );
      if (await canLaunchUrl(appleMapsUri)) {
        try {
          final launched = await launchUrl(
            appleMapsUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}
      }
    }

    // 3. Fallback universel : Google Maps Web (navigateur)
    final webMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    try {
      return await launchUrl(
        webMapsUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('MapLauncher error: $e');
      return false;
    }
  }
}
