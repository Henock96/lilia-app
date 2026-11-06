import 'package:google_maps_flutter/google_maps_flutter.dart';

/// En deçà (environ 1 m), la caméra n'a pas bougé : un aller-retour de flottants
/// avec la plateforme ne doit pas passer pour un déplacement.
const double _kSameSpotDegrees = 0.00001;

/// La caméra a-t-elle quitté [start] ?
///
/// C'est le seul signe de vie fiable d'une carte : le greffon n'expose aucun
/// signal « tuiles chargées », et le début d'un geste n'en est pas un. Mesuré le
/// 05/11/2026 : sur une carte morte, `onCameraMoveStarted` se déclenche sans que
/// la caméra bouge.
bool cameraHasLeft(LatLng start, LatLng target) =>
    (target.latitude - start.latitude).abs() >= _kSameSpotDegrees ||
    (target.longitude - start.longitude).abs() >= _kSameSpotDegrees;
