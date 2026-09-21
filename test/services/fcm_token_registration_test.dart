// L'enregistrement du jeton FCM — **combien de requêtes partent réellement.**
//
// Deux déclencheurs légitimes pointent sur la même méthode : la fin d'`init()`
// (au démarrage) et l'ouverture de session (`SessionEffects`). Sans garde, une
// connexion rapide les faisait se croiser et produisait deux
// `POST /notifications/register-token` identiques, chacun avec sa salve de
// cinq tentatives.
//
// Ce fichier exerce le **vrai** `NotificationService` contre un `ApiClient`
// moqué, et compte les requêtes. C'est possible depuis que `_fcm` et
// `_localNotifications` sont `late final` : la classe était auparavant
// inconstructible sans `Firebase.initializeApp()`, et sa logique
// d'idempotence n'aurait pu être vérifiée qu'en la recopiant dans un double —
// c'est-à-dire pas du tout.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/services/notification_service.dart';

import '../features/auth/fake_auth_repository.dart';

const _route = '/notifications/register-token';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository auth;
  late ProviderContainer container;
  late int requetes;

  /// Construit le vrai service, branché sur un client qui ne sort pas.
  ///
  /// ⚠️ Le comptage se fait par un **intercepteur**, pas dans le rappel de
  /// `DioAdapter.onPost` : celui-ci est évalué à l'enregistrement de la route,
  /// pas à l'arrivée d'une requête. Compter dedans mesurait le nombre de
  /// montages du harnais — une sonde qui répond toujours « 1 ».
  NotificationService monter({AppUser? session, bool serveurEnPanne = false}) {
    requetes = 0;
    auth = FakeAuthRepository(user: session);
    final client = ApiClient.test(
      baseUrl: 'https://test.local',
      tokenProvider: () async => 'jeton',
      forceRefreshToken: () async => 'jeton',
    );
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == _route) requetes++;
          handler.next(options);
        },
      ),
    );
    DioAdapter(dio: client.dio).onPost(
      _route,
      (server) => serveurEnPanne
          ? server.reply(500, {'message': 'Boom'})
          : server.reply(201, {'data': null}),
      data: Matchers.any,
    );

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        apiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    return container.read(notificationServiceProvider);
  }

  test('sans session, aucune requête ne part', () async {
    final service = monter();
    service.fcmToken = 'jeton-appareil';

    await service.registerTokenOnServer();

    expect(
      requetes,
      0,
      reason:
          'un jeton appartient à un compte ; sans session le serveur répond '
          '401, et cinq tentatives avec backoff coûtaient cinquante secondes '
          'de requêtes vouées à l’échec au premier lancement',
    );
  });

  test('avec session, le jeton part une fois', () async {
    final service = monter(session: const AppUser(uid: 'uid-a'));
    service.fcmToken = 'jeton-appareil';

    await service.registerTokenOnServer();

    expect(requetes, 1);
  });

  test(
    '6 — deux appels successifs sur le même jeton : une seule requête',
    () async {
      final service = monter(session: const AppUser(uid: 'uid-a'));
      service.fcmToken = 'jeton-appareil';

      await service.registerTokenOnServer();
      await service.registerTokenOnServer();
      await service.registerTokenOnServer();

      expect(
        requetes,
        1,
        reason: 'le rattachement est déjà confirmé, il n’y a rien à redire',
      );
    },
  );

  test(
    '6 bis — deux appels CONCURRENTS partagent la même requête',
    () async {
      final service = monter(session: const AppUser(uid: 'uid-a'));
      service.fcmToken = 'jeton-appareil';

      // Le cas réel : `init()` termine son `unawaited(registerTokenOnServer())`
      // à l'instant où la session s'ouvre et déclenche le sien.
      await Future.wait([
        service.registerTokenOnServer(),
        service.registerTokenOnServer(),
      ]);

      expect(requetes, 1);
    },
  );

  test('4 — un NOUVEAU jeton est enregistré, même après un premier', () async {
    final service = monter(session: const AppUser(uid: 'uid-a'));
    service.fcmToken = 'jeton-1';
    await service.registerTokenOnServer();
    expect(requetes, 1);

    // Ce que fait `onTokenRefresh` : Firebase fait tourner le jeton.
    service.fcmToken = 'jeton-2';
    await service.registerTokenOnServer();

    expect(
      requetes,
      2,
      reason:
          'la déduplication porte sur la cible, pas sur « une requête a déjà '
          'eu lieu » — sinon le serveur garderait l’ancien jeton',
    );
  });

  test(
    'après une fermeture de session, le même jeton est réenregistré',
    () async {
      final service = monter(session: const AppUser(uid: 'uid-a'));
      service.fcmToken = 'jeton-appareil';
      await service.registerTokenOnServer();
      expect(requetes, 1);

      // Le compte B arrive sur le même téléphone : le jeton n'a pas changé,
      // mais son rattachement, si.
      service.forgetRegisteredToken();
      await service.registerTokenOnServer();

      expect(requetes, 2);
    },
  );

  test('un échec ne marque pas le jeton comme enregistré', () async {
    final service = monter(
      session: const AppUser(uid: 'uid-a'),
      serveurEnPanne: true,
    );
    service.fcmToken = 'jeton-appareil';

    // Une seule tentative : le backoff réel (5 s, 10 s, 15 s, 20 s) n'a pas sa
    // place dans un test unitaire.
    await service.registerTokenOnServer(maxRetries: 1);
    expect(requetes, 1);

    // La garde ne doit pas retenir un rattachement qui n'a jamais abouti :
    // sans quoi un enregistrement raté au démarrage ne serait jamais rattrapé.
    await service.registerTokenOnServer(maxRetries: 1);

    expect(
      requetes,
      2,
      reason: 'un jeton refusé par le serveur doit être reproposé',
    );
  });
}
