import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

class LocationService {
  Position? _lastPosition;

  Position? get lastPosition => _lastPosition;

  Future<void> init() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 8));

      // Mise à jour en continu en arrière-plan (faible consommation)
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 50,
        ),
      ).listen((pos) => _lastPosition = pos);
    } catch (_) {
      // GPS indisponible — pas bloquant
    }
  }
}

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => LocationService();
