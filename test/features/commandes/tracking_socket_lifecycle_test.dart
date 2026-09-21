// **Un socket ouvert doit avoir une raison de l'être.**
//
// `unwatch` retirait la commande de la liste suivie mais ne fermait jamais la
// connexion. Le service étant `keepAlive`, consulter une commande en cours
// puis revenir à l'accueil laissait un WebSocket actif pour le reste de la
// vie de l'application — avec sa reconnexion automatique (10 tentatives,
// backoff 2 s → 10 s). De la batterie et de la data, en continu, pour une
// course que plus aucun écran ne regarde.
//
// Le défaut ne se voyait qu'appareil en main, en regardant la consommation.
// D'où la fabrique injectable : la connexion est simulée, le cycle de vie est
// réel.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/commandes/data/tracking_socket_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
// `Manager` n'est pas réexporté par `socket_io_client.dart`, et il est
// pourtant indispensable ici : `socket.onError(...)` est une extension qui
// passe par `socket.io` — le gestionnaire de connexion — et non par le socket.
// Sans lui, le câblage du service lève et rien n'est installé.
// ignore: implementation_imports
import 'package:socket_io_client/src/manager.dart' show Manager;

import '../auth/fake_auth_repository.dart';

/// Le gestionnaire de connexion, derrière le socket.
class _FauxManager implements Manager {
  @override
  dynamic Function() on(String event, dynamic handler) => () => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => this;
}

/// Socket simulé : on ne compte que ce qui décide du cycle de vie.
///
/// ⚠️ `on` est implémenté **explicitement**, et pas laissé à `noSuchMethod`.
///
/// `onConnect` / `onConnectError` / `onDisconnect` sont des extensions
/// (`DartySocket`) : elles appellent `on(...)` et **retournent son résultat**
/// en le typant `Function()`. Un `noSuchMethod` qui rend `this` faisait lever
/// « type '_FauxSocket' is not a subtype of type '() => dynamic' » dès le
/// premier `..onConnect(...)` — et le service attrape cette exception.
///
/// Conséquence, tant que ce double est resté naïf : le câblage d'événements
/// était **silencieusement mort** dans ces tests, qui passaient quand même
/// parce qu'ils n'interrogeaient que `socketOuvert` et `disposes`.
class _FauxSocket implements sio.Socket {
  _FauxSocket({this.connexionImmediate = true});

  /// Le vrai socket.io ne rend PAS `connected == true` au retour de
  /// `connect()` : il faut la poignée de main. Poser ce drapeau à `false`
  /// reproduit cette fenêtre — celle où la course de connexion se joue.
  final bool connexionImmediate;

  int disposes = 0;
  bool connecte = false;

  /// Les gestionnaires posés par le service, par nom d'événement.
  final handlers = <String, dynamic>{};

  @override
  Manager io = _FauxManager();

  @override
  bool get connected => connecte;

  @override
  dynamic Function() on(String event, dynamic handler) {
    handlers[event] = handler;
    return () => null;
  }

  /// Joue un événement du transport, comme le ferait le serveur.
  void declencher(String event, [dynamic data]) =>
      (handlers[event] as dynamic)?.call(data);

  /// La poignée de main aboutit — ce que `connect()` ne fait pas tout seul
  /// quand [connexionImmediate] est `false`.
  void etablirLaConnexion() {
    connecte = true;
    declencher('connect');
  }

  @override
  sio.Socket connect() {
    if (connexionImmediate) etablirLaConnexion();
    return this;
  }

  @override
  void dispose() {
    disposes++;
    connecte = false;
  }

  /// `emit`, `off`… : le service en appelle une douzaine pour se câbler.
  /// Aucun autre n'intéresse ce fichier.
  @override
  dynamic noSuchMethod(Invocation invocation) => this;
}

void main() {
  late FakeAuthRepository auth;
  late List<_FauxSocket> sockets;

  TrackingSocketService monter() {
    auth = FakeAuthRepository(user: const AppUser(uid: 'uid-a'));
    sockets = [];
    return TrackingSocketService(
      auth,
      fabrique: (url, options) {
        final s = _FauxSocket();
        sockets.add(s);
        return s;
      },
    );
  }

  /// `watch` ouvre la connexion de façon asynchrone (il attend le jeton).
  Future<void> laisserConnecter() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('suivre une commande ouvre une connexion', () async {
    final service = monter();

    service.watch('cmd-1');
    await laisserConnecter();

    expect(service.socketOuvert, isTrue);
    expect(sockets, hasLength(1));
  });

  test('cesser de suivre la DERNIÈRE commande ferme la connexion', () async {
    final service = monter();
    service.watch('cmd-1');
    await laisserConnecter();

    service.unwatch('cmd-1');

    expect(
      service.socketOuvert,
      isFalse,
      reason:
          'le service est keepAlive : sans fermeture ici, le socket vivait '
          'jusqu’à la fin de l’application',
    );
    expect(sockets.single.disposes, 1);
    expect(service.isWatching, isFalse);
  });

  test('tant qu’une commande reste suivie, la connexion tient', () async {
    final service = monter();
    service.watch('cmd-1');
    service.watch('cmd-2');
    await laisserConnecter();

    service.unwatch('cmd-1');

    expect(
      service.socketOuvert,
      isTrue,
      reason: 'cmd-2 est toujours suivie — fermer la couperait',
    );

    service.unwatch('cmd-2');
    expect(service.socketOuvert, isFalse);
  });

  test('resuivre après fermeture rouvre une connexion', () async {
    final service = monter();
    service.watch('cmd-1');
    await laisserConnecter();
    service.unwatch('cmd-1');
    expect(service.socketOuvert, isFalse);

    service.watch('cmd-2');
    await laisserConnecter();

    expect(service.socketOuvert, isTrue);
    expect(sockets, hasLength(2), reason: 'une seconde connexion, bien ouverte');
  });

  test('dispose ferme tout et ne laisse aucun flux ouvert', () async {
    final service = monter();
    final flux = service.watch('cmd-1');
    await laisserConnecter();

    service.dispose();

    expect(service.socketOuvert, isFalse);
    expect(service.isWatching, isFalse);
    await expectLater(flux.position, emitsDone);
    await expectLater(flux.status, emitsDone);
  });

  test('sans session, aucune connexion n’est ouverte', () async {
    auth = FakeAuthRepository();
    final service = TrackingSocketService(
      auth,
      fabrique: (url, options) => _FauxSocket(),
    );

    service.watch('cmd-1');
    await laisserConnecter();

    expect(
      service.socketOuvert,
      isFalse,
      reason: 'le namespace /tracking s’authentifie par le jeton Firebase',
    );
  });

  // ── La course de connexion ────────────────────────────────────────────────
  //
  // `_isConnecting` était relâché dans un `finally` posé juste après
  // `connect()`, donc AVANT que la poignée de main aboutisse. Pendant tout ce
  // temps `isConnected` vaut `false` : un `watch()` survenu dans cette fenêtre
  // passait les deux gardes, jetait le socket en cours d'ouverture, et en
  // créait un second.
  //
  // ⚠️ L'attente entre les deux `watch` fait le test. Deux appels
  // **synchrones** ne peuvent pas courir — `_isConnecting` est posé avant le
  // premier `await`, le second sort immédiatement. La fenêtre s'ouvre une fois
  // `_ensureConnected()` revenue.
  test('un second suivi pendant la poignée de main ne rouvre rien', () async {
    auth = FakeAuthRepository(user: const AppUser(uid: 'uid-a'));
    final crees = <_FauxSocket>[];
    final service = TrackingSocketService(
      auth,
      fabrique: (url, options) {
        final s = _FauxSocket(connexionImmediate: false);
        crees.add(s);
        return s;
      },
    );

    service.watch('cmd-1');
    await laisserConnecter();
    expect(crees, hasLength(1));
    expect(crees.single.connected, isFalse, reason: 'poignée de main en cours');

    // Le client ouvre une seconde commande avant que la première soit établie.
    service.watch('cmd-2');
    await laisserConnecter();

    expect(
      crees,
      hasLength(1),
      reason: 'un socket en cours d’ouverture est un socket dont on attend la '
          'connexion — il n’y a rien à refaire',
    );
    expect(
      crees.single.disposes,
      0,
      reason: 'et surtout : on ne jette pas celui qu’on vient de créer',
    );

    // La connexion aboutit : les DEUX commandes sont réabonnées.
    crees.single.etablirLaConnexion();
    expect(service.isWatching, isTrue);
  });

  test('un socket définitivement mort peut être remplacé', () async {
    // Garde-fou du correctif ci-dessus : la garde ne doit PAS devenir
    // « un socket existe, donc on ne fait rien ». Après dix tentatives
    // infructueuses socket.io laisse un socket vivant et déconnecté, et c'est
    // exactement le cas où il faut en refaire un.
    final service = monter();
    service.watch('cmd-1');
    await laisserConnecter();
    expect(sockets, hasLength(1));

    service.unwatch('cmd-1'); // ferme la connexion
    service.watch('cmd-2');
    await laisserConnecter();

    expect(sockets, hasLength(2), reason: 'un nouveau suivi rouvre');
  });
}
