import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/delivery_tracking_repository.dart';

const LatLng _kBrazzavilleCenter = LatLng(-4.2634, 15.2429);

/// Résout les coords de destination pour la carte :
/// - en priorité l'adresse client renvoyée par le backend (`order.deliveryLat/Lng`)
/// - sinon le GPS actuel du client (avec permission)
/// - sinon le centre de Brazzaville (fallback safe).
Future<LatLng> _resolveClientDestination(DriverLocation location) async {
  if (location.destinationLatitude != null &&
      location.destinationLongitude != null) {
    return LatLng(
      location.destinationLatitude!,
      location.destinationLongitude!,
    );
  }
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return _kBrazzavilleCenter;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return _kBrazzavilleCenter;
  }
}

/// Construit les 3 markers de tracking (livreur / restaurant / destination
/// client) partagés par la carte inline et la carte plein écran.
/// [detailed] ajoute les snippets (mode plein écran).
Set<Marker> _buildTrackingMarkers(
  DriverLocation loc,
  LatLng? destination, {
  required bool detailed,
}) {
  final markers = <Marker>{};

  if (loc.hasDriverPosition) {
    markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: LatLng(loc.latitude!, loc.longitude!),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: InfoWindow(
        title: loc.driverNom ?? 'Livreur',
        snippet: loc.etaMinutes != null
            ? 'Arrive dans ${loc.etaMinutes} min'
            : 'Votre livreur',
      ),
    ));
  }

  if (loc.hasRestaurant) {
    markers.add(Marker(
      markerId: const MarkerId('restaurant'),
      position: LatLng(loc.restaurantLatitude!, loc.restaurantLongitude!),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: InfoWindow(
        title: loc.restaurantNom ?? 'Restaurant',
        snippet: detailed ? 'Point de retrait' : null,
      ),
    ));
  }

  if (destination != null) {
    markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: destination,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: 'Adresse de livraison',
        snippet: detailed ? 'Vous' : null,
      ),
    ));
  }

  return markers;
}

/// Trace la route pointillée livreur → destination (si les deux sont connus).
Set<Polyline> _buildRoutePolyline(
  DriverLocation loc,
  LatLng? destination, {
  required int width,
  required int dash,
  required int gap,
}) {
  final polylines = <Polyline>{};
  if (loc.hasDriverPosition && destination != null) {
    polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: [LatLng(loc.latitude!, loc.longitude!), destination],
      color: const Color(0xFF1565C0),
      width: width,
      patterns: [PatternItem.dash(dash.toDouble()), PatternItem.gap(gap.toDouble())],
    ));
  }
  return polylines;
}

/// Centre initial de la caméra : livreur > destination > restaurant > Brazzaville.
LatLng _initialMapCenter(DriverLocation loc, LatLng? destination) {
  return loc.hasDriverPosition
      ? LatLng(loc.latitude!, loc.longitude!)
      : (destination ??
          (loc.hasRestaurant
              ? LatLng(loc.restaurantLatitude!, loc.restaurantLongitude!)
              : _kBrazzavilleCenter));
}

class DriverTrackingMap extends ConsumerWidget {
  final String orderId;
  final bool fullscreen;
  const DriverTrackingMap({
    super.key,
    required this.orderId,
    this.fullscreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final locationAsync = ref.watch(driverLocationControllerProvider(orderId));

    if (fullscreen) {
      return locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Impossible de récupérer la position',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref
                    .read(driverLocationControllerProvider(orderId).notifier)
                    .refresh(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (location) {
          if (location == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_searching, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'En attente d\'attribution d\'un livreur…',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return _FullscreenMapView(location: location);
        },
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
                  child: const Icon(
                    Icons.delivery_dining,
                    color: Colors.indigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Livreur en route',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Position mise à jour en temps réel',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
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
            error: (_, _) => _NoPositionPlaceholder(
              message: 'Impossible de récupérer la position',
              onRetry: () => ref
                  .read(driverLocationControllerProvider(orderId).notifier)
                  .refresh(),
            ),
            data: (location) {
              if (location == null) {
                return const _NoPositionPlaceholder(
                  message: 'En attente d\'attribution d\'un livreur…',
                );
              }
              return _MapView(location: location);
            },
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
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'LIVE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
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
  LatLng? _destination;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _initDestination();
  }

  Future<void> _initDestination() async {
    final dest = await _resolveClientDestination(widget.location);
    if (!mounted) return;
    setState(() => _destination = dest);
    _fitBounds();

    // Stream du GPS client uniquement si on n'a PAS de coords backend
    // (sinon la destination est fixe = adresse de la commande).
    if (widget.location.destinationLatitude == null) {
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() => _destination = LatLng(p.latitude, p.longitude));
      });
    }
  }

  void _fitBounds() {
    if (_ctrl == null || _destination == null) return;
    final dest = _destination!;
    final points = <LatLng>[
      dest,
      if (widget.location.hasDriverPosition)
        LatLng(widget.location.latitude!, widget.location.longitude!),
      if (widget.location.hasRestaurant)
        LatLng(
          widget.location.restaurantLatitude!,
          widget.location.restaurantLongitude!,
        ),
    ];
    if (points.length < 2) return;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    Future.delayed(const Duration(milliseconds: 300), () {
      _ctrl?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.005,
                lngs.reduce((a, b) => a < b ? a : b) - 0.005),
            northeast: LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.005,
                lngs.reduce((a, b) => a > b ? a : b) + 0.005),
          ),
          80,
        ),
      );
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
    final loc = widget.location;
    final markers = _buildTrackingMarkers(loc, _destination, detailed: true);
    final polylines =
        _buildRoutePolyline(loc, _destination, width: 5, dash: 20, gap: 10);
    final initialCenter = _initialMapCenter(loc, _destination);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initialCenter, zoom: 15),
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
        ),
        if (!loc.hasDriverPosition)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.95),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'En attente de la position du livreur…',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
  LatLng? _destination;

  @override
  void initState() {
    super.initState();
    _initDestination();
  }

  Future<void> _initDestination() async {
    final dest = await _resolveClientDestination(widget.location);
    if (mounted) setState(() => _destination = dest);
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final markers = _buildTrackingMarkers(loc, _destination, detailed: false);
    final polylines =
        _buildRoutePolyline(loc, _destination, width: 4, dash: 16, gap: 8);
    final initialCenter = _initialMapCenter(loc, _destination);

    return SizedBox(
      height: 220,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: initialCenter, zoom: 15),
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
    if (location.driverNom == null &&
        location.driverPhone == null &&
        location.driverImageUrl == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: location.driverImageUrl != null
                ? NetworkImage(location.driverImageUrl!)
                : null,
            child: location.driverImageUrl == null
                ? const Icon(Icons.person, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location.driverNom != null)
                  Text(
                    location.driverNom!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                Row(
                  children: [
                    if (location.etaMinutes != null &&
                        location.etaMinutes! > 0) ...[
                      Icon(Icons.schedule, size: 12, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Arrive dans ${location.etaMinutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (location.updatedAt != null)
                      Text(
                        'il y a ${_minutesAgo(location.updatedAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (location.driverPhone != null)
            IconButton(
              onPressed: () =>
                  launchUrl(Uri.parse('tel:${location.driverPhone}')),
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
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ],
      ),
    ),
  );
}
