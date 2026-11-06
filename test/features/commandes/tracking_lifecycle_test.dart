// **Un suivi de livraison ne doit pas tourner pendant que l'écran dort.**
//
// `unwatch` ferme bien le socket quand plus aucune commande n'est suivie —
// c'était le correctif P2-007. Mais il ne couvre pas l'autre cas, celui où
// l'écran **reste monté** : le client bascule vers WhatsApp pendant sa
// livraison, et le poll HTTP de 30 s comme le WebSocket continuent. Sur une
// course de quarante minutes passée pour l'essentiel en arrière-plan, c'est
// quatre-vingts requêtes inutiles et une connexion permanente.
//
// iOS suspend le processus, donc l'impact y est borné ; c'est Android qui
// paie — sur des forfaits où la data et la batterie comptent.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/network/interceptors/retry_interceptor.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/commandes/data/delivery_tracking_repository.dart';
import 'package:lilia_app/features/commandes/data/tracking_socket_service.dart';

import '../auth/fake_auth_repository.dart';

const _orderId = 'cmd-1';

/// Compte les lectures HTTP du suivi, et pilote le statut renvoyé.
class _AdaptateurSuivi implements HttpClientAdapter {
  int appels = 0;
  String deliveryStatus = 'EN_TRANSIT';

  /// Horodatage de la dernière position servie par HTTP.
  DateTime? lastPositionAt;

  /// Réponse du serveur : 200, 404 (aucune livraison) ou 500 (panne).
  int codeHttp = 200;

  /// Retient la lecture tant qu'il n'est pas complété.
  Completer<void>? barriere;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    appels++;
    await barriere?.future;
    if (codeHttp != 200) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'refus'}),
        codeHttp,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'id': 'liv-1',
          'status': deliveryStatus,
          'lastLatitude': -4.26,
          'lastLongitude': 15.28,
          if (lastPositionAt != null)
            'lastPositionAt': lastPositionAt!.toUtc().toIso8601String(),
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Service de suivi qui n'ouvre aucune connexion : on n'observe ici que les
/// abonnements et désabonnements, qui sont ce que le cycle de vie décide.
class _SocketEspion implements TrackingSocketService {
  final suivis = <String>[];
  final abandonnes = <String>[];

  /// Positions poussées par le « serveur » WebSocket.
  final positions = StreamController<DriverPositionEvent>.broadcast();

  @override
  ({Stream<DriverPositionEvent> position, Stream<String> status}) watch(
    String orderId,
  ) {
    suivis.add(orderId);
    return (
      position: positions.stream,
      status: const Stream<String>.empty(),
    );
  }

  @override
  void unwatch(String orderId) => abandonnes.add(orderId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late _AdaptateurSuivi reseau;
  late _SocketEspion socket;
  late ProviderContainer container;

  setUp(() {
    reseau = _AdaptateurSuivi();
    socket = _SocketEspion();
    final client = ApiClient(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'jeton',
      forceRefreshToken: () async => 'jeton',
    );
    client.dio.httpClientAdapter = reseau;
    // Un 500 coûterait 2,8 s de relances par lecture : sans elle, un test finit
    // avant la relecture qu'il croit observer.
    client.dio.interceptors.removeWhere((i) => i is RetryInterceptor);

    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        trackingSocketServiceProvider.overrideWithValue(socket),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: const AppUser(uid: 'uid-a')),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Ouvre l'écran de suivi, comme le ferait `FullscreenTrackingScreen`.
  Future<void> ouvrirLeSuivi() async {
    addTearDown(
      container.listen(driverLocationControllerProvider(_orderId), (_, _) {}).close,
    );
    await container.read(driverLocationControllerProvider(_orderId).future);
  }

  /// Laisse retomber l'aller-retour Dio de la reprise — la relecture précède
  /// le réabonnement, et ce n'est pas qu'une micro-tâche.
  Future<void> pompes() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// ⚠️ Flutter **valide** les transitions de cycle de vie : `paused →
  /// resumed` n'existe pas. Le système passe par `inactive` et `hidden` dans
  /// les deux sens, et sauter une étape fait ignorer l'événement — un test qui
  /// le ferait observerait « rien ne s'est produit » et conclurait à tort.
  Future<void> cycleDeVie(List<AppLifecycleState> chemin) async {
    for (final etat in chemin) {
      binding.handleAppLifecycleStateChanged(etat);
      await Future<void>.delayed(Duration.zero);
    }
    await pompes();
  }

  /// Le client bascule vers une autre application.
  Future<void> passerEnArrierePlan() => cycleDeVie(const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);

  /// Il revient.
  Future<void> revenirAuPremierPlan() => cycleDeVie(const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

  test('arrière-plan : le suivi se met en veille', () async {
    await ouvrirLeSuivi();
    expect(socket.suivis, [_orderId]);
    expect(reseau.appels, 1);

    await passerEnArrierePlan();

    expect(
      socket.abandonnes,
      [_orderId],
      reason: 'la connexion temps réel n’a plus d’objet : personne ne regarde',
    );
  });

  test('premier plan : le suivi relit PUIS se réabonne', () async {
    await ouvrirLeSuivi();
    await passerEnArrierePlan();
    final appelsAvant = reseau.appels;

    await revenirAuPremierPlan();

    expect(
      reseau.appels,
      appelsAvant + 1,
      reason: 'la position affichée date d’avant la veille : attendre le '
          'prochain événement montrerait un livreur immobile là où il n’est '
          'plus',
    );
    expect(
      socket.suivis,
      [_orderId, _orderId],
      reason: 'et le temps réel reprend',
    );
  });

  test('inactif ou masqué : rien ne bouge', () async {
    // Un appel entrant, le sélecteur d'applications, une bascule de fenêtre.
    // Couper dessus ferait clignoter le suivi à chaque notification système.
    await ouvrirLeSuivi();

    await cycleDeVie(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(socket.abandonnes, isEmpty);
    expect(reseau.appels, 1);
  });

  test('course terminée pendant la veille : on ne rouvre pas', () async {
    await ouvrirLeSuivi();
    await passerEnArrierePlan();

    // Le livreur a fini pendant que le téléphone dormait.
    reseau.deliveryStatus = 'LIVRER';
    await revenirAuPremierPlan();

    expect(
      socket.suivis,
      [_orderId],
      reason: 'la relecture suffit à l’apprendre — rouvrir un socket pour une '
          'course achevée serait exactement ce qu’on vient de corriger',
    );
  });

  test('course déjà terminée à l’ouverture : aucun suivi n’est ouvert',
      () async {
    reseau.deliveryStatus = 'LIVRER';
    await ouvrirLeSuivi();

    expect(
      socket.suivis,
      isEmpty,
      reason: 'l’historique est plus consulté que le suivi live : une commande '
          'd’il y a trois mois ne doit ouvrir aucune connexion',
    );
  });

  // ─── C-23 — audit du 09/10/2026 ─────────────────────────────────────────

  test('repli HTTP : la fin de course est appliquée et le suivi coupé',
      () async {
    DriverLocationController.httpFallbackInterval =
        const Duration(milliseconds: 20);
    addTearDown(
      () => DriverLocationController.httpFallbackInterval =
          const Duration(seconds: 30),
    );
    await ouvrirLeSuivi();
    expect(socket.suivis, [_orderId]);

    // Le WebSocket ne dit rien ; seul le repli HTTP voit la livraison finie.
    reseau.deliveryStatus = 'LIVRER';
    final avant = reseau.appels;
    await Future<void>.delayed(const Duration(milliseconds: 35));
    await pompes();

    expect(reseau.appels, avant + 1);
    expect(
      container.read(driverLocationControllerProvider(_orderId)).value
          ?.deliveryStatus,
      'LIVRER',
    );
    expect(socket.abandonnes, contains(_orderId));

    // Plus aucune lecture : le minuteur est arrêté.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(reseau.appels, avant + 1);
  });

  // Revue du 10/10/2026 : le repli HTTP écrivait `state` sans mettre à jour
  // la référence du garde-fou C-22 ; une position WS rejouée, plus ancienne
  // que celle affichée, faisait reculer le livreur.
  test('WS → HTTP plus récent → WS rejoué plus ancien : pas de recul',
      () async {
    DriverLocationController.httpFallbackInterval =
        const Duration(milliseconds: 20);
    addTearDown(
      () => DriverLocationController.httpFallbackInterval =
          const Duration(seconds: 30),
    );
    final t1 = DateTime.utc(2026, 10, 10, 12, 0);
    final t2 = DateTime.utc(2026, 10, 10, 12, 2);
    final t3 = DateTime.utc(2026, 10, 10, 12, 4);

    reseau.lastPositionAt = t1;
    await ouvrirLeSuivi();

    reseau.lastPositionAt = t3;
    await Future<void>.delayed(const Duration(milliseconds: 35));
    await pompes();
    final provider = driverLocationControllerProvider(_orderId);
    expect(container.read(provider).value?.updatedAt, t3);

    socket.positions.add(
      DriverPositionEvent(lat: -4.0, lng: 15.0, timestamp: t2),
    );
    await pompes();

    expect(container.read(provider).value?.updatedAt, t3);
  });

  // ─── Audit du 05/11/2026 — une panne n'est pas une absence ──────────────

  final suivi = driverLocationControllerProvider(_orderId);

  void repliRapide() {
    DriverLocationController.httpFallbackInterval =
        const Duration(milliseconds: 20);
    addTearDown(
      () => DriverLocationController.httpFallbackInterval =
          const Duration(seconds: 30),
    );
  }

  Future<void> laisserTournerLeRepli() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await pompes();
  }

  /// Ouvre le suivi sur un serveur en panne : la première lecture échoue.
  Future<void> ouvrirEnPanne() async {
    reseau.codeHttp = 500;
    addTearDown(container.listen(suivi, (_, _) {}).close);
    await expectLater(container.read(suivi.future), throwsA(isA<ApiException>()));
  }

  group('aucune livraison (404)', () {
    setUp(() => reseau.codeHttp = 404);

    test('à l’ouverture : rien à afficher, aucune connexion', () async {
      await ouvrirLeSuivi();

      expect(container.read(suivi).hasError, isFalse);
      expect(container.read(suivi).value, isNull);
      expect(
        socket.suivis,
        isEmpty,
        reason: 'un retrait au comptoir n’a jamais de livraison : ni socket, '
            'ni poll pour lui',
      );
    });

    // LILIA-FOOD-APP-CLIENT-E : `_socket!` sur null à la reprise.
    test('retour au premier plan : relit, sans planter ni s’abonner', () async {
      await ouvrirLeSuivi();
      await passerEnArrierePlan();

      await revenirAuPremierPlan();

      expect(reseau.appels, 2);
      expect(socket.suivis, isEmpty);
    });

    test('relecture ratée au retour : toujours rien à suivre', () async {
      await ouvrirLeSuivi();
      await passerEnArrierePlan();

      reseau.codeHttp = 500;
      await revenirAuPremierPlan();

      expect(socket.suivis, isEmpty);
    });

    test('livreur assigné pendant la veille : le suivi s’ouvre au retour',
        () async {
      await ouvrirLeSuivi();
      await passerEnArrierePlan();

      reseau.codeHttp = 200;
      await revenirAuPremierPlan();

      expect(container.read(suivi).value?.deliveryId, 'liv-1');
      expect(socket.suivis, [_orderId]);
    });
  });

  test('course terminée à l’ouverture, relecture ratée au retour : aucun suivi',
      () async {
    reseau.deliveryStatus = 'LIVRER';
    await ouvrirLeSuivi();
    await passerEnArrierePlan();

    reseau.codeHttp = 500;
    await revenirAuPremierPlan();

    expect(socket.suivis, isEmpty);
  });

  group('première lecture en panne', () {
    test('l’erreur est visible : ce n’est pas « aucun livreur »', () async {
      await ouvrirEnPanne();

      expect(container.read(suivi).hasError, isTrue);
    });

    test('Riverpod ne relance pas : le repli s’en charge sans couper le socket',
        () async {
      await ouvrirEnPanne();
      final appels = reseau.appels;

      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(reseau.appels, appels);
      expect(socket.abandonnes, isEmpty);
    });

    test('le suivi repart seul quand le serveur revient', () async {
      repliRapide();
      await ouvrirEnPanne();
      expect(socket.suivis, [_orderId]);

      reseau.codeHttp = 200;
      await laisserTournerLeRepli();

      expect(container.read(suivi).hasError, isFalse);
      expect(container.read(suivi).value?.deliveryId, 'liv-1');
      expect(socket.suivis, [_orderId], reason: 'aucun second abonnement');
    });

    test('le serveur revient sans livraison : on coupe tout', () async {
      repliRapide();
      await ouvrirEnPanne();

      reseau.codeHttp = 404;
      await laisserTournerLeRepli();
      final appels = reseau.appels;
      await laisserTournerLeRepli();

      expect(container.read(suivi).hasError, isFalse);
      expect(container.read(suivi).value, isNull);
      expect(socket.abandonnes, [_orderId]);
      expect(reseau.appels, appels, reason: 'plus aucune lecture');
    });

    test('une position reçue pendant la panne n’empêche pas le contexte',
        () async {
      repliRapide();
      await ouvrirEnPanne();

      socket.positions.add(
        DriverPositionEvent(
          lat: -4.0,
          lng: 15.0,
          timestamp: DateTime.utc(2026, 11, 6, 12, 5),
        ),
      );
      await pompes();
      expect(container.read(suivi).value?.deliveryId, isNull);

      reseau
        ..codeHttp = 200
        ..lastPositionAt = DateTime.utc(2026, 11, 6, 12);
      await laisserTournerLeRepli();

      final etat = container.read(suivi).value;
      expect(
        etat?.deliveryId,
        'liv-1',
        reason: 'livreur, destination et code de remise n’arrivent que par HTTP',
      );
      expect(
        etat?.updatedAt,
        DateTime.utc(2026, 11, 6, 12, 5),
        reason: 'une lecture plus ancienne ne recule pas le livreur (C-22)',
      );
      expect(etat?.latitude, -4.0);
    });

    test('en veille puis retour : le suivi reprend et se rattrape', () async {
      await ouvrirEnPanne();
      await passerEnArrierePlan();

      reseau.codeHttp = 200;
      await revenirAuPremierPlan();

      expect(container.read(suivi).value?.deliveryId, 'liv-1');
      expect(socket.suivis, [_orderId, _orderId]);
    });

    test('toujours en panne au retour : le suivi reste branché', () async {
      await ouvrirEnPanne();
      await passerEnArrierePlan();

      await revenirAuPremierPlan();

      expect(container.read(suivi).hasError, isTrue);
      expect(socket.suivis, [_orderId, _orderId]);
    });
  });

  group('refus définitif (403)', () {
    Future<void> ouvrirRefuse() async {
      reseau.codeHttp = 403;
      addTearDown(container.listen(suivi, (_, _) {}).close);
      await expectLater(
        container.read(suivi.future),
        throwsA(isA<ApiException>()),
      );
    }

    test('l’erreur se voit, et rien ne tourne pour la rattraper', () async {
      await ouvrirRefuse();

      expect(container.read(suivi).hasError, isTrue);
      expect(
        socket.suivis,
        isEmpty,
        reason: 'attendre ne changera rien : socket et poll coûteraient de la '
            'data et de la batterie pour toute la durée de l’écran',
      );
    });

    test('retour au premier plan : toujours rien', () async {
      await ouvrirRefuse();
      await passerEnArrierePlan();

      await revenirAuPremierPlan();

      expect(socket.suivis, isEmpty);
    });
  });

  test('retour pendant la première lecture : un seul abonnement', () async {
    final barriere = reseau.barriere = Completer<void>();
    addTearDown(container.listen(suivi, (_, _) {}).close);
    await pompes();

    await passerEnArrierePlan();
    await revenirAuPremierPlan();
    barriere.complete();
    await pompes();

    expect(socket.suivis, [_orderId]);
  });

  test('retour pendant la première lecture d’un retrait : aucun abonnement',
      () async {
    final barriere = reseau.barriere = Completer<void>();
    reseau.codeHttp = 404;
    addTearDown(container.listen(suivi, (_, _) {}).close);
    await pompes();

    await passerEnArrierePlan();
    await revenirAuPremierPlan();
    barriere.complete();
    await pompes();

    expect(socket.suivis, isEmpty);
  });

  test('écran fermé pendant « Réessayer » : rien n’est écrit après coup',
      () async {
    final ecoute = container.listen(suivi, (_, _) {});
    reseau.codeHttp = 500;
    await expectLater(container.read(suivi.future), throwsA(isA<ApiException>()));

    final barriere = reseau.barriere = Completer<void>();
    final relecture = container.read(suivi.notifier).refresh();
    await pompes();
    ecoute.close();
    await pompes();

    barriere.complete();
    await relecture;
  });

  test('écran fermé pendant la première lecture : aucun abonnement', () async {
    final barriere = reseau.barriere = Completer<void>();
    final ecoute = container.listen(suivi, (_, _) {});
    await pompes();

    ecoute.close();
    await pompes();
    barriere.complete();
    await pompes();

    expect(socket.suivis, isEmpty);
  });

  test('arrière-plan pendant la première lecture : un seul abonnement au retour',
      () async {
    final barriere = reseau.barriere = Completer<void>();
    addTearDown(container.listen(suivi, (_, _) {}).close);
    await pompes();

    await passerEnArrierePlan();
    barriere.complete();
    await pompes();
    expect(socket.suivis, isEmpty, reason: 'personne ne regarde');

    await revenirAuPremierPlan();

    expect(socket.suivis, [_orderId]);
  });
}

