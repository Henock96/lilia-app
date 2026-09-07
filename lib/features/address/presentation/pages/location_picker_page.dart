import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/services/location_service.dart';

/// Position choisie par le client, rendue par [LocationPickerPage].
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.landmark,
  });

  final double latitude;
  final double longitude;

  /// Repères saisis à la main : « portail bleu face à la pharmacie ».
  final String? landmark;
}

/// Centre par défaut de la carte : Brazzaville.
///
/// ⚠️ C'est un **cadrage initial**, pas une position. Il n'est jamais rendu
/// comme résultat : tant que le client n'a pas déplacé la carte ou confirmé,
/// rien n'est validé. La distinction est ce qui sépare cet écran de l'ancien
/// repli « centre de Brazzaville » qui faisait passer un point arbitraire pour
/// une adresse.
const LatLng _kBrazzavilleFraming = LatLng(-4.2634, 15.2429);

/// Zoom auquel on distingue les rues — poser un repère à l'échelle de la ville
/// n'aurait aucun sens.
const double _kStreetZoom = 17;

/// Choix d'une position sur la carte.
///
/// ## Le geste
///
/// Le repère est **fixe au centre de l'écran** et c'est la carte qui glisse
/// dessous. Ce choix n'est pas cosmétique : un marqueur qu'on fait glisser au
/// doigt est masqué par ce même doigt au moment précis où l'on vise, et sur un
/// écran de 5 pouces la précision obtenue est pire que celle du GPS qu'on
/// cherchait à corriger.
///
/// ## Ce que cet écran ne fait pas
///
/// Il n'appelle **aucun service de géocodage inverse**. Testé le 01/09/2026
/// sur cinq points de Brazzaville : Google rend un Plus Code (« P6PV+J5 ») dans
/// trois cas sur cinq. Afficher « P6PV+J5 » à la place de l'adresse saisie par
/// le client serait une régression. La position est la donnée primaire,
/// l'adresse textuelle reste celle qu'il écrit.
class LocationPickerPage extends ConsumerStatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialPosition,
    this.quartier,
    this.initialLandmark,
    this.title = 'Placez le repère',
  });

  /// Position déjà connue — modification d'une adresse existante.
  final LatLng? initialPosition;

  /// Quartier sélectionné : sert au cadrage initial quand aucune position
  /// n'est connue, et n'est affiché que pour situer le client.
  final Quartier? quartier;

  final String? initialLandmark;
  final String title;

  @override
  ConsumerState<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends ConsumerState<LocationPickerPage> {
  GoogleMapController? _controller;
  late final TextEditingController _landmarkController;

  /// Centre courant de la carte — c'est lui qui sera confirmé.
  late LatLng _center;

  /// `true` tant que le client n'a ni déplacé la carte ni utilisé son GPS.
  /// Le bouton de confirmation reste désactivé : on ne veut pas qu'un tap
  /// distrait enregistre le cadrage par défaut comme si c'était une adresse.
  bool _touched = false;

  bool _locating = false;

  /// `true` quand la carte n'a donné aucun signe de vie dans le délai imparti.
  ///
  /// ## Le mode de panne que ceci rattrape
  ///
  /// Le bouton de confirmation est verrouillé tant que le client n'a pas
  /// déplacé la carte. C'est voulu — un tap distrait ne doit pas enregistrer
  /// le cadrage par défaut. Mais si la carte ne s'affiche **pas** (clé Maps
  /// invalide en release, Services Google Play absents ou périmés, quota
  /// dépassé), il n'y a rien à déplacer : le verrou ne s'ouvre jamais, aucune
  /// erreur n'est affichée, et le client se retrouve devant un rectangle gris
  /// et un bouton grisé. Il ne peut plus enregistrer d'adresse du tout, et
  /// rien ne lui dit pourquoi ni comment s'en sortir.
  ///
  /// Google Maps ne signale pas ces échecs à l'application. On les déduit donc
  /// du silence, et on offre une issue plutôt qu'un cul-de-sac.
  bool _mapSeemsBroken = false;

  Timer? _mapWatchdog;

  /// Au-delà, on considère que la carte ne viendra pas. Large : sur la 4G de
  /// Brazzaville, les premières tuiles prennent parfois plusieurs secondes.
  static const _mapWatchdogDelay = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _landmarkController = TextEditingController(
      text: widget.initialLandmark ?? '',
    );
    _center = widget.initialPosition ?? _kBrazzavilleFraming;
    // Une position déjà enregistrée est un choix antérieur du client : la
    // reconfirmer sans la déplacer est légitime.
    _touched = widget.initialPosition != null;

    if (!_touched) {
      _mapWatchdog = Timer(_mapWatchdogDelay, () {
        if (mounted && !_touched) setState(() => _mapSeemsBroken = true);
      });
    }
  }

  /// Le client a donné signe de vie : la carte fonctionne, on désarme.
  void _markTouched() {
    _mapWatchdog?.cancel();
    if (!_touched || _mapSeemsBroken) {
      setState(() {
        _touched = true;
        _mapSeemsBroken = false;
      });
    }
  }

  @override
  void dispose() {
    _mapWatchdog?.cancel();
    _controller?.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  /// Option A du parcours : « Utiliser ma position ».
  ///
  /// Aide au cadrage, rien de plus — le repère reste déplaçable ensuite, et
  /// c'est bien le centre final qui est confirmé. Sur Android 12+, une
  /// autorisation « approximative » rend un point à 1–3 km : sans ce
  /// déplacement possible, l'adresse serait fausse sans que personne le sache.
  Future<void> _useCurrentPosition() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final target = LatLng(
      result.position!.latitude,
      result.position!.longitude,
    );
    setState(() => _center = target);
    _markTouched();
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _kStreetZoom),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _center.latitude,
        longitude: _center.longitude,
        landmark: _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: widget.initialPosition != null
                        ? _kStreetZoom
                        : // Sans position connue, on cadre plus large : montrer
                          // une rue au hasard suggérerait qu'elle a été choisie.
                          13,
                  ),
                  onMapCreated: (c) => _controller = c,
                  // La caméra n'est jamais repositionnée par le code après ce
                  // point : la carte appartient au doigt du client.
                  onCameraMove: (position) => _center = position.target,
                  onCameraMoveStarted: _markTouched,
                  // `false` volontairement.
                  //
                  // À `true`, le greffon réclame la permission de localisation
                  // **dès l'ouverture** de la carte, avant que le client ait
                  // touché quoi que ce soit — donc une demande système sans
                  // contexte, à laquelle on répond « refuser » par réflexe. Or
                  // le refus définitif d'Android ne se redemande pas.
                  //
                  // La permission est réclamée par « Utiliser ma position »,
                  // qui est le geste qui l'explique. Le point bleu n'est de
                  // toute façon pas nécessaire ici : ce qu'on pose, c'est
                  // l'adresse de livraison, pas la position du téléphone.
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  tiltGesturesEnabled: false,
                ),

                // Repère fixe. Décalé d'une demi-hauteur vers le haut pour que
                // la *pointe* de l'épingle tombe sur le centre géométrique de
                // la carte, et non son milieu : sans ce décalage le point
                // enregistré est systématiquement au sud du point visé.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: cs.primary,
                      shadows: const [
                        Shadow(color: Colors.black38, blurRadius: 6),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'locate-me',
                    tooltip: 'Utiliser ma position',
                    onPressed: _locating ? null : _useCurrentPosition,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),

                if (_mapSeemsBroken)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _MapUnavailableNotice(
                      onSkip: () => Navigator.of(context).pop(),
                    ),
                  )
                else if (!_touched)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _Hint(
                      text: widget.quartier != null
                          ? 'Déplacez la carte pour placer le repère sur votre '
                                'porte à ${widget.quartier!.nom}.'
                          : 'Déplacez la carte pour placer le repère sur votre '
                                'porte.',
                    ),
                  ),
              ],
            ),
          ),
          _BottomPanel(
            quartier: widget.quartier,
            landmarkController: _landmarkController,
            canConfirm: _touched,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }
}

/// Ce qu'on affiche quand la carte n'est jamais venue.
///
/// Le message ne prétend pas savoir pourquoi — l'application ne le sait pas :
/// Google Maps n'informe pas d'une clé invalide ni de Services Play absents.
/// Il dit ce qui est observable, et surtout il **rend la main** : l'adresse
/// reste enregistrable sans position, le serveur retombera sur le centroïde du
/// quartier. Un cul-de-sac silencieux était la seule chose à ne pas laisser.
class _MapUnavailableNotice extends StatelessWidget {
  const _MapUnavailableNotice({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.map_outlined, size: 18, color: cs.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'La carte ne se charge pas. Vérifiez votre connexion, ou '
                    'enregistrez votre adresse sans position — le livreur sera '
                    'guidé à votre quartier et vous appellera.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onErrorContainer,
                ),
                child: const Text('Continuer sans position'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: cs.surface.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.quartier,
    required this.landmarkController,
    required this.canConfirm,
    required this.onConfirm,
  });

  final Quartier? quartier;
  final TextEditingController landmarkController;
  final bool canConfirm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quartier != null) ...[
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      quartier!.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Le champ de repères n'est pas un supplément décoratif : à
              // Brazzaville, « portail bleu face à la pharmacie » situe une
              // porte mieux qu'un numéro de rue, et il voyage jusqu'à l'écran
              // du livreur (`Order.deliveryLandmark`).
              TextField(
                controller: landmarkController,
                maxLength: 300,
                minLines: 1,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Repères pour le livreur (facultatif)',
                  hintText: 'Ex : portail bleu face à la pharmacie',
                  counterText: '',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canConfirm ? onConfirm : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmer cette position'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (!canConfirm)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Déplacez la carte ou utilisez votre position pour activer '
                    'la confirmation.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
