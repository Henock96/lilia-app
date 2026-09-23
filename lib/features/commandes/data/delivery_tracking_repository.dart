import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:lilia_app/models/location_precision.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../notifications/application/notification_providers.dart';
import 'order_controller.dart';
import 'tracking_socket_service.dart';
import 'package:lilia_app/core/log.dart';

part 'delivery_tracking_repository.g.dart';

/// État de tracking d'une commande côté UI.
///
/// Construit depuis l'endpoint HTTP `GET /deliveries/by-order/:orderId`
/// (fallback initial + sync 30s) et mis à jour via WebSocket `/tracking`
/// (`DriverPositionEvent` toutes les ~5s).
///
/// Le backend renvoie (`findByOrderId`) :
/// ```
/// {
///   id, status, lastLatitude, lastLongitude, lastPositionAt,
///   estimatedArrival, acceptedAt, pickedUpAt, deliveredAt, createdAt,
///   deliverer: { id, nom, phone, imageUrl },
///   review: { id, rating, createdAt } | null,
///   order: {
///     id,
///     deliveryLatitude, deliveryLongitude,
///     restaurant: { id, nom, latitude, longitude },
///   },
/// }
/// ```
class DriverLocation {
  /// Identifiant de la livraison — nécessaire pour noter le livreur.
  final String? deliveryId;

  /// Statut de la livraison tel que le backend le connaît :
  /// `ASSIGNER` / `ACCEPTER` / `EN_TRANSIT` / `LIVRER` / `ECHEC`.
  ///
  /// Sert à afficher où en est réellement la course. `ACCEPTER` signifie que le
  /// livreur va chercher la commande — pas qu'il roule vers le client.
  final String? deliveryStatus;

  /// Note déjà laissée par le client sur cette livraison, s'il y en a une.
  final int? myRating;

  /// Dernière position connue du livreur. `null` si le livreur n'a pas
  /// encore émis (mission acceptée mais pas encore en route, GPS pas prêt).
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  // Infos livreur (depuis `deliverer` imbriqué).
  final String? driverNom;
  final String? driverPhone;
  final String? driverImageUrl;

  // ETA en minutes (event WS ou calcul backend).
  final int? etaMinutes;

  // Destination = adresse client, résolue par le serveur à la commande
  // (`order.deliveryLatitude/Longitude`). Ce n'est plus le GPS du téléphone.
  final double? destinationLatitude;
  final double? destinationLongitude;

  /// Fiabilité de la destination, telle que figée sur la commande.
  ///
  /// Sans elle, un centroïde de quartier s'afficherait exactement comme un
  /// point posé à la main — c'est ce que faisait la version précédente.
  final LocationPrecision destinationPrecision;

  /// Adresse lisible et repères du client, recopiés sur la commande.
  final String? destinationAddress;
  final String? destinationLandmark;

  // Restaurant (point de départ logique de la livraison).
  final String? restaurantNom;
  final double? restaurantLatitude;
  final double? restaurantLongitude;

  /// Code de remise à 4 chiffres (Master Audit v1, F-06).
  ///
  /// Le serveur ne le renvoie qu'au CLIENT, et seulement pendant que le repas
  /// roule vers lui. Le client le donne au livreur à la porte : c'est ce qui
  /// prouve que la commande lui a été remise.
  final String? handoverCode;

  const DriverLocation({
    this.deliveryId,
    this.deliveryStatus,
    this.myRating,
    this.latitude,
    this.longitude,
    this.updatedAt,
    this.driverNom,
    this.driverPhone,
    this.driverImageUrl,
    this.etaMinutes,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationPrecision = LocationPrecision.unknown,
    this.destinationAddress,
    this.destinationLandmark,
    this.restaurantNom,
    this.restaurantLatitude,
    this.restaurantLongitude,
    this.handoverCode,
  });

  /// `true` ssi on a une position GPS exploitable du livreur.
  bool get hasDriverPosition => latitude != null && longitude != null;

  /// Le livreur a le repas en main et roule vers le client.
  bool get isOnTheWay => deliveryStatus == 'EN_TRANSIT';

  /// Le livreur a accepté la mission mais va encore chercher la commande.
  /// C'est la nuance que l'app annonçait à tort comme « en route ».
  bool get isHeadingToRestaurant => deliveryStatus == 'ACCEPTER';

  /// La commande a été remise : la notation du livreur devient possible.
  bool get isDelivered => deliveryStatus == 'LIVRER';

  /// Le client peut encore noter cette livraison.
  bool get canRateDriver => isDelivered && myRating == null;

  /// Libellé d'avancement affiché au client, honnête sur ce qui se passe.
  String get progressLabel => switch (deliveryStatus) {
    'ASSIGNER' => 'Un livreur a été assigné à votre commande',
    'ACCEPTER' => 'Le livreur va récupérer votre commande',
    'EN_TRANSIT' => 'Votre commande est en route',
    'LIVRER' => 'Commande livrée',
    'ECHEC' => 'Incident de livraison',
    _ => 'Préparation en cours',
  };

  /// `true` ssi le backend a renvoyé l'adresse client géocodée.
  bool get hasDestination =>
      destinationLatitude != null && destinationLongitude != null;

  /// `true` ssi le backend a renvoyé les coords du restaurant.
  bool get hasRestaurant =>
      restaurantLatitude != null && restaurantLongitude != null;

  factory DriverLocation.fromHttpJson(Map<String, dynamic> json) {
    final deliverer = json['deliverer'] as Map<String, dynamic>?;
    final order = json['order'] as Map<String, dynamic>?;
    final restaurant = order?['restaurant'] as Map<String, dynamic>?;

    final review = json['review'] as Map<String, dynamic>?;

    return DriverLocation(
      deliveryId: json['id'] as String?,
      deliveryStatus: json['status'] as String?,
      myRating: (review?['rating'] as num?)?.toInt(),
      latitude: (json['lastLatitude'] as num?)?.toDouble(),
      longitude: (json['lastLongitude'] as num?)?.toDouble(),
      updatedAt: json['lastPositionAt'] != null
          ? DateTime.tryParse(json['lastPositionAt'] as String)
          : null,
      driverNom: deliverer?['nom'] as String?,
      driverPhone: deliverer?['phone'] as String?,
      driverImageUrl: deliverer?['imageUrl'] as String?,
      destinationLatitude: (order?['deliveryLatitude'] as num?)?.toDouble(),
      destinationLongitude: (order?['deliveryLongitude'] as num?)?.toDouble(),
      destinationPrecision: LocationPrecision.fromWire(
        order?['deliveryPrecision'] as String?,
      ),
      destinationAddress: order?['deliveryAddress'] as String?,
      destinationLandmark: order?['deliveryLandmark'] as String?,
      restaurantNom: restaurant?['nom'] as String?,
      restaurantLatitude: (restaurant?['latitude'] as num?)?.toDouble(),
      restaurantLongitude: (restaurant?['longitude'] as num?)?.toDouble(),
      handoverCode: json['handoverCode'] as String?,
    );
  }

  /// Met à jour la position depuis un event WebSocket en gardant le contexte
  /// commande (livreur, resto, destination) déjà chargé via HTTP.
  DriverLocation copyWithWsPosition(DriverPositionEvent event) {
    return DriverLocation(
      deliveryId: deliveryId,
      deliveryStatus: deliveryStatus,
      myRating: myRating,
      latitude: event.lat,
      longitude: event.lng,
      updatedAt: event.timestamp,
      driverNom: driverNom,
      driverPhone: driverPhone,
      driverImageUrl: driverImageUrl,
      etaMinutes: event.eta,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      destinationPrecision: destinationPrecision,
      destinationAddress: destinationAddress,
      destinationLandmark: destinationLandmark,
      restaurantNom: restaurantNom,
      restaurantLatitude: restaurantLatitude,
      restaurantLongitude: restaurantLongitude,
      // Une position WS ne porte pas le code : on garde celui lu en HTTP,
      // sinon il disparaîtrait de l'écran au premier mouvement du livreur.
      handoverCode: handoverCode,
    );
  }
}

/// Charge l'état tracking initial via HTTP.
///
/// Renvoie toujours un [DriverLocation] dès que le backend trouve la
/// livraison, même si le livreur n'a pas encore émis sa position GPS —
/// l'UI peut alors afficher déjà le marker resto + destination et
/// l'avatar livreur. `null` uniquement si le backend renvoie une erreur.
Future<DriverLocation?> fetchDriverLocation(
  String orderId,
  ApiClient api,
) async {
  try {
    final res = await api.getJson('/deliveries/by-order/$orderId');
    final data =
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return DriverLocation.fromHttpJson(data);
  } on ApiException catch (e) {
    // Contrat : null si le backend renvoie une erreur (livraison absente, etc.).
    logDebug('fetchDriverLocation: ${e.message}');
    return null;
  }
}

/// Controller qui combine WebSocket temps réel + HTTP initial.
///
/// Stratégie :
///   1. Au build : fetch HTTP pour avoir la dernière position + infos livreur
///   2. S'abonne au WebSocket `/tracking` → reçoit `driver:position` en temps réel
///   3. Chaque event WS met à jour l'état immédiatement (lag <1s vs 10s avant)
///   4. Fallback HTTP toutes les 30s en cas de coupure WS (vs 10s avant)
@riverpod
class DriverLocationController extends _$DriverLocationController
    with WidgetsBindingObserver {
  Timer? _httpFallbackTimer;
  StreamSubscription<DriverPositionEvent>? _wsPositionSub;
  StreamSubscription<String>? _wsStatusSub;
  // Debounce des invalidations de userOrdersProvider déclenchées par le WS :
  // un changement de statut peut arriver quasi-simultanément via WS et FCM, on
  // évite ainsi un double refetch de la liste de commandes (cf. B-10 / dette #2).
  Timer? _statusInvalidationDebounce;
  String? _orderId;
  // Référence capturée pendant build() : `ref.read` est interdit dans onDispose
  // (Riverpod 3.x), on garde donc le service pour pouvoir unwatch au cleanup.
  TrackingSocketService? _socket;

  /// Livraisons dont plus aucune position ni changement de statut n'arrivera.
  ///
  /// Une commande livrée reste consultable indéfiniment dans l'historique :
  /// sans cette liste, ouvrir une commande d'il y a trois mois ouvrait un
  /// WebSocket et armait un poll HTTP toutes les 30 s pour une course terminée.
  static const _terminalDeliveryStatuses = {'LIVRER', 'ECHEC'};

  /// Le suivi est en veille : l'application est passée en arrière-plan.
  bool _enVeille = false;

  /// La course est finie. Une reprise ne doit **pas** rouvrir de socket pour
  /// une livraison terminée sous les yeux du client.
  bool _termine = false;

  @override
  FutureOr<DriverLocation?> build(String orderId) async {
    _orderId = orderId;

    // ⚠️ Le suivi tournait indéfiniment en arrière-plan.
    //
    // `unwatch` ferme bien le socket quand plus aucune commande n'est suivie
    // — c'était le correctif P2-007. Mais il ne couvre pas l'autre cas, celui
    // où l'écran **reste monté** : le client bascule vers WhatsApp pendant sa
    // livraison, et le poll HTTP de 30 s et le WebSocket continuent. Sur une
    // course de quarante minutes passée pour l'essentiel en arrière-plan,
    // c'est quatre-vingts requêtes inutiles et une connexion permanente — de
    // la data et de la batterie, sur des forfaits où l'une et l'autre
    // comptent.
    //
    // iOS suspend le processus, donc l'impact y est borné ; c'est Android qui
    // paie. On ne se repose pas sur la plateforme pour une consommation qu'on
    // peut décider nous-mêmes.
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    ref.onDispose(_cleanup);

    final initial = await _fetchHttp(orderId);

    // Course terminée (ou inexistante) : rien à suivre. On rend l'état une
    // fois et on s'arrête — c'est le cas de la très grande majorité des
    // commandes consultées, l'historique étant plus lu que le suivi live.
    if (initial == null ||
        _terminalDeliveryStatuses.contains(initial.deliveryStatus)) {
      return initial;
    }

    _socket = ref.read(trackingSocketServiceProvider);
    _abonnerAuSuivi(orderId, initial);

    return initial;
  }


  /// Ouvre le suivi temps réel : abonnement WebSocket + repli HTTP.
  ///
  /// Extraite de [build] parce qu'elle sert **deux** fois — à l'ouverture de
  /// l'écran, et au retour de l'application au premier plan. Dupliquer ces
  /// trente lignes aurait garanti qu'une des deux copies finisse par diverger.
  void _abonnerAuSuivi(String orderId, DriverLocation? initial) {
    DriverLocation? current = initial ?? state.value;
    final streams = _socket!.watch(orderId);

    _wsPositionSub = streams.position.listen((event) {
      if (!ref.mounted) return;
      current =
          current?.copyWithWsPosition(event) ??
          DriverLocation(
            latitude: event.lat,
            longitude: event.lng,
            updatedAt: event.timestamp,
            etaMinutes: event.eta,
          );
      state = AsyncValue.data(current);
    });

    _wsStatusSub = streams.status.listen((status) {
      logDebug('[Tracking] order:status → $status');
      if (!ref.mounted) return;
      // La commande vient de se terminer sous nos yeux : le suivi n'a plus
      // d'objet, on coupe socket et timer plutôt que de tourner à vide jusqu'à
      // ce que l'utilisateur ferme l'écran.
      if (status == 'LIVRER' || status == 'ANNULER') {
        _stopLiveTracking();
      }
      // Le WS est fiable (<1s) ; on rafraîchit la liste de commandes ici au lieu
      // de dépendre uniquement de FCM (best-effort). Mirroir du path FCM dans
      // NotificationService : set du dernier orderId + invalidate debouncé.
      ref.read(latestUpdatedOrderIdProvider.notifier).state = orderId;
      _invalidateUserOrdersDebounced();
    });

    // Fallback HTTP plus rare — la WS prend le relai en temps normal
    _startHttpFallback(orderId);
  }

  // ─── Cycle de vie de l'application ────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `state` masque ici le champ du notifier — même contrainte de nommage
    // que `StaleForegroundStamp`. On n'y touche pas dans cette méthode ; les
    // écritures d'état passent par `_reprendre`.
    if (!ref.mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_reprendre());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _mettreEnVeille();
      // `inactive` et `hidden` sont transitoires — un appel entrant, le
      // sélecteur d'applications, une bascule de fenêtre. Couper le suivi
      // dessus le ferait clignoter à chaque notification système.
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Coupe tout ce qui consomme, sans rien oublier de ce qu'on sait.
  ///
  /// L'état courant reste affiché : au retour, le client revoit la dernière
  /// position connue le temps que la relecture aboutisse — plutôt qu'un écran
  /// vide.
  void _mettreEnVeille() {
    if (_enVeille || _termine) return;
    _enVeille = true;
    logDebug('[Tracking] arrière-plan — suivi mis en veille');
    _couperFluxEtMinuteur();
  }

  /// Rouvre le suivi, **en relisant d'abord**.
  ///
  /// La position affichée date d'avant la mise en veille : attendre le
  /// prochain événement WebSocket montrerait un livreur immobile là où il
  /// n'est plus. Une lecture HTTP immédiate coûte un aller-retour et corrige
  /// l'écran tout de suite.
  Future<void> _reprendre() async {
    if (!_enVeille || _termine) return;
    _enVeille = false;
    final id = _orderId;
    if (id == null) return;
    logDebug('[Tracking] premier plan — reprise du suivi');

    try {
      final frais = await _fetchHttp(id);
      if (!ref.mounted) return;
      if (frais != null) state = AsyncValue.data(frais);
      // Livrée pendant que le téléphone dormait : il n'y a plus rien à suivre.
      if (frais != null &&
          _terminalDeliveryStatuses.contains(frais.deliveryStatus)) {
        _termine = true;
        return;
      }
    } catch (e) {
      // Une relecture ratée ne doit pas empêcher de reprendre le temps réel :
      // c'est le WebSocket qui porte le suivi, la lecture n'est qu'un
      // rattrapage.
      logDebug('[Tracking] relecture à la reprise échouée : $e');
    }

    if (!ref.mounted || _enVeille) return;
    _abonnerAuSuivi(id, state.value);
  }

  /// Ferme flux et minuteur, sans toucher aux drapeaux ni à l'état affiché.
  void _couperFluxEtMinuteur() {
    _httpFallbackTimer?.cancel();
    _httpFallbackTimer = null;
    _wsPositionSub?.cancel();
    _wsPositionSub = null;
    _wsStatusSub?.cancel();
    _wsStatusSub = null;
    final id = _orderId;
    if (id != null) _socket?.unwatch(id);
  }

  Future<DriverLocation?> _fetchHttp(String orderId) async {
    return fetchDriverLocation(orderId, ref.read(apiClientProvider));
  }

  void _startHttpFallback(String orderId) {
    _httpFallbackTimer?.cancel();
    _httpFallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!ref.mounted) return;
      try {
        final fresh = await _fetchHttp(orderId);
        if (!ref.mounted || fresh == null) return;
        final previous = state.value;
        // N'écrase pas la position WS plus récente
        if (previous == null ||
            (fresh.updatedAt != null &&
                (previous.updatedAt == null ||
                    fresh.updatedAt!.isAfter(previous.updatedAt!)))) {
          state = AsyncValue.data(fresh);
        }
      } catch (e) {
        // Poll de fallback : on log mais on ne casse pas le timer périodique.
        logDebug('Tracking HTTP fallback: $e');
      }
    });
  }

  Future<void> refresh() async {
    if (_orderId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchHttp(_orderId!));
  }

  /// Invalide la liste **et le détail** au plus une fois par fenêtre de 600 ms
  /// (même fenêtre que le path FCM dans NotificationService).
  ///
  /// Le détail lit désormais `GET /orders/:id` : sans cette seconde
  /// invalidation, l'écran ouvert sous la carte de suivi garderait son statut
  /// d'origine pendant que le livreur avance.
  void _invalidateUserOrdersDebounced() {
    _statusInvalidationDebounce?.cancel();
    _statusInvalidationDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!ref.mounted) return;
      ref.invalidate(userOrdersProvider);
      ref.invalidate(orderDetailProvider);
    });
  }

  /// Coupe le suivi temps réel en gardant le provider vivant.
  ///
  /// Distinct de [_cleanup], qui s'exécute au dispose : ici l'écran reste
  /// affiché et doit continuer à montrer le dernier état connu.
  void _stopLiveTracking() {
    // `_termine` verrouille : une reprise de l'application ne doit pas
    // rouvrir un socket pour une course qui s'est achevée sous nos yeux.
    _termine = true;
    _couperFluxEtMinuteur();
  }

  void _cleanup() {
    _statusInvalidationDebounce?.cancel();
    // `_socket` a été capturé en build() : pas de `ref.read` pendant le
    // dispose (interdit en Riverpod 3.x).
    _couperFluxEtMinuteur();
    _socket = null;
    _orderId = null; // évite toute réutilisation d'un orderId obsolète (C14)
  }
}
