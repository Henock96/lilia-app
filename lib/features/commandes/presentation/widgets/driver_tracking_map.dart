import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lilia_app/models/location_precision.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/delivery_tracking_repository.dart';

/// Cadrage de repli quand aucun point n'est connu — **jamais** un marqueur.
///
/// La distinction est le cœur de la correction de septembre 2026 : une carte
/// centrée sur Brazzaville dit « je ne sais pas où regarder », un marqueur posé
/// à Brazzaville dit « la livraison est ici ». La version précédente faisait la
/// seconde chose, et pire encore : faute de coordonnées sur la commande, elle
/// demandait le GPS **du client en train de regarder la carte** et l'étiquetait
/// « Adresse de livraison ».
const LatLng _kBrazzavilleFraming = LatLng(-4.2634, 15.2429);

/// Destination de la course, ou `null`.
///
/// Une seule source : les coordonnées figées sur la commande par le serveur.
/// Pas de repli, pas de GPS local, pas de point inventé — si le serveur ne
/// sait pas, l'interface ne sait pas non plus et le dit.
LatLng? _destinationOf(DriverLocation location) {
  if (!location.destinationPrecision.hasPosition) return null;
  if (location.destinationLatitude == null ||
      location.destinationLongitude == null) {
    return null;
  }
  return LatLng(location.destinationLatitude!, location.destinationLongitude!);
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
    markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(loc.latitude!, loc.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: loc.driverNom ?? 'Livreur',
          snippet: loc.etaMinutes != null
              ? 'Arrive dans ${loc.etaMinutes} min'
              : 'Votre livreur',
        ),
      ),
    );
  }

  if (loc.hasRestaurant) {
    markers.add(
      Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(loc.restaurantLatitude!, loc.restaurantLongitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: loc.restaurantNom ?? 'Restaurant',
          snippet: detailed ? 'Point de retrait' : null,
        ),
      ),
    );
  }

  if (destination != null) {
    final approximate = loc.destinationPrecision.needsWarning;
    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          // Un point approximatif ne porte pas la même couleur qu'un point
          // posé : la nuance doit être lisible sans ouvrir l'infobulle.
          approximate ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueBlue,
        ),
        infoWindow: InfoWindow(
          title: approximate
              ? 'Zone de livraison (approximative)'
              : 'Adresse de livraison',
          snippet: approximate
              ? 'Position au quartier'
              : (detailed ? 'Vous' : null),
        ),
      ),
    );
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
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [LatLng(loc.latitude!, loc.longitude!), destination],
        color: const Color(0xFF1565C0),
        width: width,
        patterns: [
          PatternItem.dash(dash.toDouble()),
          PatternItem.gap(gap.toDouble()),
        ],
      ),
    );
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
                // Dernier recours : on cadre la ville. Aucun marqueur n'y est
                // posé, la carte montre seulement « quelque part à
                // Brazzaville » — ce qui est exactement ce qu'on sait.
                : _kBrazzavilleFraming));
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
          return _TrackingMapView(location: location, fullscreen: true);
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
              return _TrackingMapView(location: location, fullscreen: false);
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

/// Carte de tracking partagée entre l'affichage inline (carte de la commande)
/// et l'affichage plein écran. Le mode [fullscreen] ajoute : contrôleur caméra
/// + recadrage automatique sur les points (`_fitBounds`), suivi du GPS client
/// en temps réel (si la destination n'est pas fixée par le backend), overlay
/// « en attente du livreur » et contrôles de zoom. En mode inline, la carte a
/// une hauteur fixe et un rendu plus épuré.
class _TrackingMapView extends StatefulWidget {
  final DriverLocation location;
  final bool fullscreen;
  const _TrackingMapView({required this.location, required this.fullscreen});

  @override
  State<_TrackingMapView> createState() => _TrackingMapViewState();
}

class _TrackingMapViewState extends State<_TrackingMapView> {
  GoogleMapController? _ctrl; // plein écran uniquement (recadrage)
  LatLng? _destination;

  bool get _fullscreen => widget.fullscreen;

  @override
  void initState() {
    super.initState();
    // La destination est une donnée de la commande, connue immédiatement :
    // plus d'appel asynchrone, plus de permission demandée, plus de flux GPS.
    //
    // L'ancienne version ouvrait un `getPositionStream` sur le téléphone du
    // **client** dès que la commande n'avait pas de coordonnées, et déplaçait
    // le marqueur « Adresse de livraison » à chaque pas qu'il faisait. Le
    // serveur résolvant désormais la destination, il n'y a plus rien à
    // deviner ici.
    _destination = _destinationOf(widget.location);
    if (_fullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  @override
  void didUpdateWidget(covariant _TrackingMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La destination peut apparaître entre deux rafraîchissements : le premier
    // appel HTTP peut précéder l'assignation du livreur.
    final next = _destinationOf(widget.location);
    if (next != _destination) setState(() => _destination = next);
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
            southwest: LatLng(
              lats.reduce((a, b) => a < b ? a : b) - 0.005,
              lngs.reduce((a, b) => a < b ? a : b) - 0.005,
            ),
            northeast: LatLng(
              lats.reduce((a, b) => a > b ? a : b) + 0.005,
              lngs.reduce((a, b) => a > b ? a : b) + 0.005,
            ),
          ),
          80,
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final markers = _buildTrackingMarkers(
      loc,
      _destination,
      detailed: _fullscreen,
    );
    final polylines = _fullscreen
        ? _buildRoutePolyline(loc, _destination, width: 5, dash: 20, gap: 10)
        : _buildRoutePolyline(loc, _destination, width: 4, dash: 16, gap: 8);
    final initialCenter = _initialMapCenter(loc, _destination);

    final map = GoogleMap(
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: 15),
      onMapCreated: _fullscreen
          ? (c) {
              _ctrl = c;
              _fitBounds();
            }
          : null,
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: _fullscreen,
      mapToolbarEnabled: false,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: false,
    );

    if (!_fullscreen) {
      return Column(
        children: [
          SizedBox(height: 220, child: map),
          _DestinationNotice(location: loc),
        ],
      );
    }

    return Stack(
      children: [
        map,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _DestinationNotice(location: loc),
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
              tooltip: 'Appeler',
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

/// Dit au client ce que la carte montre vraiment.
///
/// Silencieux quand la destination est un point posé : il n'y a rien à
/// signaler, et un bandeau permanent finirait par ne plus être lu. Il ne parle
/// que dans les deux cas où la carte, seule, induirait en erreur — un marqueur
/// approximatif, ou pas de marqueur du tout.
class _DestinationNotice extends StatelessWidget {
  const _DestinationNotice({required this.location});

  final DriverLocation location;

  @override
  Widget build(BuildContext context) {
    final precision = location.destinationPrecision;
    if (precision == LocationPrecision.exact) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final approximate = precision == LocationPrecision.approximate;

    return Container(
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(
            approximate ? Icons.gps_not_fixed : Icons.gps_off,
            size: 15,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              approximate
                  ? 'Position approximative — le livreur vous appellera en '
                        'arrivant dans le quartier.'
                  : 'Adresse non située sur la carte — le livreur vous '
                        'appellera.',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
