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

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
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

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    appels++;
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'id': 'liv-1',
          'status': deliveryStatus,
          'lastLatitude': -4.26,
          'lastLongitude': 15.28,
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

  @override
  ({Stream<DriverPositionEvent> position, Stream<String> status}) watch(
    String orderId,
  ) {
    suivis.add(orderId);
    return (
      position: const Stream<DriverPositionEvent>.empty(),
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
}
