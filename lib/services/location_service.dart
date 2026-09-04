import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

/// Pourquoi la position n'est pas disponible.
///
/// Chaque cas appelle une action différente de la part du client : rallumer la
/// localisation, réessayer, ou passer par les réglages système. Les confondre
/// en un seul `null` ne lui permettait de rien faire — c'est exactement ce que
/// faisait la version précédente, dont le `catch (_) {}` avalait tout.
enum LocationDenialReason {
  /// La localisation de l'appareil est éteinte.
  serviceDisabled,

  /// Refus ponctuel : redemander est possible.
  denied,

  /// Refus définitif : seul un passage par les réglages débloque.
  deniedForever,

  /// Autorisation accordée, mais aucun point obtenu dans le délai imparti.
  timeout,
}

/// Résultat d'une demande de position.
class LocationResult {
  const LocationResult.success(Position this.position) : reason = null;
  const LocationResult.failure(this.reason) : position = null;

  final Position? position;
  final LocationDenialReason? reason;

  bool get isSuccess => position != null;

  /// Message affichable tel quel, formulé côté client.
  String get message => switch (reason) {
    LocationDenialReason.serviceDisabled =>
      'La localisation de votre téléphone est désactivée. Activez-la, ou '
          'placez le repère à la main sur la carte.',
    LocationDenialReason.deniedForever =>
      "L'accès à votre position est bloqué. Autorisez-le dans les réglages, "
          'ou placez le repère à la main sur la carte.',
    LocationDenialReason.denied =>
      'Sans accès à votre position, vous pouvez toujours placer le repère à '
          'la main sur la carte.',
    LocationDenialReason.timeout =>
      'Position introuvable pour le moment. Placez le repère à la main sur '
          'la carte.',
    null => '',
  };
}

/// Accès au GPS du téléphone.
///
/// ## Ce que ce service n'est plus
///
/// Il ne s'initialise **plus au démarrage** de l'application et ne conserve
/// **plus** de « dernière position connue ». Les deux comportements se
/// tenaient : la position mise en cache au lancement servait de destination de
/// livraison au checkout, ce qui envoyait le livreur là où le client se
/// trouvait au moment de payer.
///
/// La destination appartient désormais à l'adresse, résolue par le serveur.
/// Le GPS ne sert plus qu'à **une** chose : pré-centrer la carte quand le
/// client vient poser le repère de son adresse. C'est un confort, jamais une
/// source de vérité — d'où l'appel à la demande plutôt qu'en continu.
///
/// Corollaire : la permission est demandée au moment où elle sert, sur un
/// écran qui explique pourquoi, et non sur l'écran de démarrage.
class LocationService {
  /// Au-delà, on rend la main : mieux vaut une carte à recentrer à la main
  /// qu'un écran figé sur un GPS qui ne répond pas.
  static const _timeout = Duration(seconds: 10);

  /// Demande la position courante, en sollicitant la permission si besoin.
  Future<LocationResult> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failure(
        LocationDenialReason.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(LocationDenialReason.deniedForever);
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return const LocationResult.failure(LocationDenialReason.denied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        // `high` et non `medium` : ce point sert à poser un repère d'adresse.
        // Sur Android 12+, une autorisation « approximative » rend malgré tout
        // un point à 1–3 km — d'où le repère déplaçable, qui reste le dernier
        // mot du client.
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(_timeout);
      return LocationResult.success(position);
    } catch (_) {
      return const LocationResult.failure(LocationDenialReason.timeout);
    }
  }
}

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => LocationService();
