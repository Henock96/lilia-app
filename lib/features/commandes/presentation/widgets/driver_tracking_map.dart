import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/delivery_tracking_repository.dart';

class DriverTrackingMap extends ConsumerWidget {
  final String orderId;
  final bool fullscreen;
  const DriverTrackingMap({super.key, required this.orderId, this.fullscreen = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final locationAsync = ref.watch(driverLocationControllerProvider(orderId));

    if (fullscreen) {
      return locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Impossible de récupérer la position', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(driverLocationControllerProvider(orderId).notifier).refresh(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (location) => location == null
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_searching, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Position GPS en cours d\'acquisition...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : _FullscreenMapView(location: location),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delivery_dining, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Livreur en route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Position mise à jour en temps réel', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _LiveBadge(),
              ],
            ),
          ),

          // Carte ou état de chargement
          locationAsync.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _NoPositionPlaceholder(
              message: 'Impossible de récupérer la position',
              onRetry: () => ref.read(driverLocationControllerProvider(orderId).notifier).refresh(),
            ),
            data: (location) => location == null
                ? const _NoPositionPlaceholder(message: 'Position GPS en cours d\'acquisition...')
                : _MapView(location: location),
          ),

          // Infos livreur
          locationAsync.whenData((loc) => loc).value != null
              ? _DriverInfo(location: locationAsync.value!)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      );
}

class _FullscreenMapView extends StatefulWidget {
  final DriverLocation location;
  const _FullscreenMapView({required this.location});

  @override
  State<_FullscreenMapView> createState() => _FullscreenMapViewState();
}

class _FullscreenMapViewState extends State<_FullscreenMapView> {
  GoogleMapController? _ctrl;
  LatLng? _clientPos;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _initClientPosition();
  }

  Future<void> _initClientPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _clientPos = const LatLng(-4.2634, 15.2429));
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _clientPos = LatLng(pos.latitude, pos.longitude));
      _fitBounds();

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
      ).listen((p) {
        if (!mounted) return;
        setState(() => _clientPos = LatLng(p.latitude, p.longitude));
      });
    } catch (_) {
      if (mounted) setState(() => _clientPos = const LatLng(-4.2634, 15.2429));
    }
  }

  void _fitBounds() {
    if (_ctrl == null || _clientPos == null) return;
    final driver = LatLng(widget.location.latitude, widget.location.longitude);
    final client = _clientPos!;
    Future.delayed(const Duration(milliseconds: 300), () {
      _ctrl?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            [driver.latitude, client.latitude].reduce((a, b) => a < b ? a : b) - 0.005,
            [driver.longitude, client.longitude].reduce((a, b) => a < b ? a : b) - 0.005,
          ),
          northeast: LatLng(
            [driver.latitude, client.latitude].reduce((a, b) => a > b ? a : b) + 0.005,
            [driver.longitude, client.longitude].reduce((a, b) => a > b ? a : b) + 0.005,
          ),
        ),
        80,
      ));
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverPos = LatLng(widget.location.latitude, widget.location.longitude);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: widget.location.driverNom ?? 'Livreur', snippet: 'Votre livreur'),
      ),
      if (_clientPos != null)
        Marker(
          markerId: const MarkerId('client'),
          position: _clientPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Vous', snippet: 'Votre position'),
        ),
    };
    final polylines = _clientPos != null
        ? {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [driverPos, _clientPos!],
              color: const Color(0xFF1565C0),
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          }
        : <Polyline>{};

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: driverPos, zoom: 15),
      onMapCreated: (c) {
        _ctrl = c;
        _fitBounds();
      },
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: false,
    );
  }
}

class _MapView extends StatefulWidget {
  final DriverLocation location;
  const _MapView({required this.location});

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  LatLng? _clientPos;

  @override
  void initState() {
    super.initState();
    _fetchClientPos();
  }

  Future<void> _fetchClientPos() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _clientPos = const LatLng(-4.2634, 15.2429));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) setState(() => _clientPos = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      if (mounted) setState(() => _clientPos = const LatLng(-4.2634, 15.2429));
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverPos = LatLng(widget.location.latitude, widget.location.longitude);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: widget.location.driverNom ?? 'Livreur', snippet: 'Votre livreur'),
      ),
      if (_clientPos != null)
        Marker(
          markerId: const MarkerId('client'),
          position: _clientPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Vous'),
        ),
    };
    final polylines = _clientPos != null
        ? {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [driverPos, _clientPos!],
              color: const Color(0xFF1565C0),
              width: 4,
              patterns: [PatternItem.dash(16), PatternItem.gap(8)],
            ),
          }
        : <Polyline>{};

    return SizedBox(
      height: 220,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: driverPos, zoom: 15),
        markers: markers,
        polylines: polylines,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: false,
      ),
    );
  }
}

class _DriverInfo extends StatelessWidget {
  final DriverLocation location;
  const _DriverInfo({required this.location});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (location.driverNom == null && location.driverPhone == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.surfaceContainerHighest,
            child: const Icon(Icons.person, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location.driverNom != null)
                  Text(location.driverNom!, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (location.updatedAt != null)
                  Text(
                    'Mis à jour il y a ${_minutesAgo(location.updatedAt!)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (location.driverPhone != null)
            IconButton(
              onPressed: () => launchUrl(Uri.parse('tel:${location.driverPhone}')),
              icon: const Icon(Icons.call),
              style: IconButton.styleFrom(
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                foregroundColor: Colors.green,
              ),
            ),
        ],
      ),
    );
  }

  String _minutesAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    return '${diff.inMinutes}min';
  }
}

class _NoPositionPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _NoPositionPlaceholder({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        height: 140,
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_searching, size: 36, color: Colors.grey),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onRetry, child: const Text('Réessayer')),
              ],
            ],
          ),
        ),
      );
}

