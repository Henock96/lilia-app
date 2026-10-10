// Sign in with Apple — le **vrai** `FirebaseAuthenticationRepository`.
//
// Les autres tests Apple doublent le dépôt entier ; ceux-ci le font tourner
// pour de bon, au-dessus d'un `FirebaseAuth` doublé et de la vraie chaîne
// `ApiClient` (interceptors compris, réseau remplacé par un adaptateur). Ils
// fixent ce qui ne se voit dans aucun écran :
//
//  - les scopes demandés à Apple (sans `name`, le nom n'arrive jamais) ;
//  - le rafraîchissement du jeton à la création, qui porte le nom au serveur ;
//  - `/users/sync` : même politique d'échec que Google, parrainage à la
//    création seulement ;
//  - la décision « ce compte est-il lié à Apple ? » avant une suppression, et
//    la traduction des échecs de révocation.
//
// Les doubles Firebase n'implémentent que ce que le dépôt doit appeler : tout
// autre appel lève, au lieu de passer pour un succès silencieux.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

const _relais = 'x7k2p9@privaterelay.appleid.com';

void main() {
  late _FakeAuth auth;
  late ApiClient api;
  late List<RequestOptions> requetes;
  late FirebaseAuthenticationRepository repo;

  /// Réponse du faux serveur à `/users/sync`.
  void serveurRepond(int statut) {
    api.dio.httpClientAdapter = _StubAdapter(
      status: statut,
      body: statut < 400
          ? '{"data":{"isNew":true}}'
          : '{"success":false,"message":"Erreur serveur"}',
      onRequest: requetes.add,
    );
  }

  void serveurInjoignable() {
    api.dio.httpClientAdapter = _StubAdapter(
      status: 0,
      body: '',
      onRequest: requetes.add,
      erreurReseau: true,
    );
  }

  setUp(() {
    requetes = [];
    auth = _FakeAuth();
    api = ApiClient(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'jeton',
      forceRefreshToken: () async => 'jeton',
    );
    serveurRepond(200);
    repo = FirebaseAuthenticationRepository(auth, GoogleSignIn.instance, api);
  });

  Map<String, dynamic> corpsSync() {
    final req = requetes.singleWhere((r) => r.path == '/users/sync');
    final data = req.data;
    return (data is String ? jsonDecode(data) : data) as Map<String, dynamic>;
  }

  group('signInWithApple', () {
    test('demande l’adresse ET le nom à Apple', () async {
      auth.reponse = _cred(_FakeUser(email: _relais), nouveau: true);

      await repo.signInWithApple();

      final fournisseur = auth.dernierFournisseur;
      expect(fournisseur, isA<AppleAuthProvider>());
      expect((fournisseur! as AppleAuthProvider).scopes,
          containsAll(<String>['email', 'name']));
    });

    test('création avec nom : jeton rafraîchi avant /users/sync, parrainage '
        'transmis, adresse relais conservée', () async {
      final user = _FakeUser(email: _relais, displayName: 'Jean Dupont');
      auth.reponse = _cred(user, nouveau: true);

      final appUser = await repo.signInWithApple(referralCode: 'PARRAIN8');

      expect(user.rafraichissements, 1);
      expect(corpsSync()['referralCode'], 'PARRAIN8');
      expect(appUser.email, _relais);
      expect(appUser.uid, user.uid);
    });

    test('connexion suivante : Apple ne rend plus le nom — aucun '
        'rafraîchissement, parrainage ignoré, connexion réussie', () async {
      final user = _FakeUser(email: _relais);
      auth.reponse = _cred(user, nouveau: false);

      final appUser = await repo.signInWithApple(referralCode: 'PARRAIN8');

      expect(user.rafraichissements, 0);
      expect(corpsSync().containsKey('referralCode'), isFalse);
      expect(appUser.displayName, isNull);
    });

    test('création sans nom (non partagé) : pas de rafraîchissement inutile',
        () async {
      final user = _FakeUser(email: _relais);
      auth.reponse = _cred(user, nouveau: true);

      await repo.signInWithApple();

      expect(user.rafraichissements, 0);
      expect(requetes.where((r) => r.path == '/users/sync'), hasLength(1));
    });

    test('rafraîchissement du jeton en échec : non bloquant', () async {
      final user = _FakeUser(email: _relais, displayName: 'Jean')
        ..echecRafraichissement = true;
      auth.reponse = _cred(user, nouveau: true);

      await expectLater(repo.signInWithApple(), completes);
      expect(requetes.where((r) => r.path == '/users/sync'), hasLength(1));
    });

    // C-02 — audit du 09/10/2026 : la synchronisation est « en vol » pendant
    // `/users/sync`, et seulement pendant.
    test('synchronisation signalée en vol pendant /users/sync, puis close',
        () async {
      bool? pendantSync;
      api.dio.httpClientAdapter = _StubAdapter(
        status: 200,
        body: '{"data":{"isNew":true}}',
        onRequest: (r) {
          requetes.add(r);
          pendantSync = repo.synchronisationEnCours;
        },
      );
      auth.reponse = _cred(_FakeUser(email: _relais), nouveau: true);

      expect(repo.synchronisationEnCours, isFalse);
      await repo.signInWithApple();

      expect(pendantSync, isTrue);
      expect(repo.synchronisationEnCours, isFalse);
      await expectLater(repo.attendreSynchronisation(), completes);
    });

    test('synchronisation close même quand /users/sync échoue', () async {
      auth.reponse = _cred(_FakeUser(email: _relais), nouveau: true);
      serveurRepond(500);

      await expectLater(repo.signInWithApple(), throwsA(isA<AuthFailure>()));
      expect(repo.synchronisationEnCours, isFalse);
    });

    test('création + échec serveur : compte Firebase supprimé, échec remonté',
        () async {
      final user = _FakeUser(email: _relais);
      auth.reponse = _cred(user, nouveau: true);
      serveurRepond(500);

      await expectLater(repo.signInWithApple(), throwsA(isA<AuthFailure>()));
      expect(user.supprime, isTrue,
          reason: 'sinon un compte Firebase orphelin, sans ligne en base');
    });

    test('compte existant + échec serveur : jamais supprimé, session '
        'conservée', () async {
      final user = _FakeUser(email: _relais);
      auth.reponse = _cred(user, nouveau: false);
      serveurRepond(500);

      await expectLater(repo.signInWithApple(), completes);
      expect(user.supprime, isFalse);
    });

    test('compte existant + réseau coupé : échec réseau, jamais supprimé',
        () async {
      final user = _FakeUser(email: _relais);
      auth.reponse = _cred(user, nouveau: false);
      serveurInjoignable();

      await expectLater(
        repo.signInWithApple(),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.network)),
      );
      expect(user.supprime, isFalse);
    });

    test('feuille fermée / conflit de compte : l’échec Firebase remonte, '
        'aucun appel au serveur', () async {
      for (final code in [
        'canceled',
        'account-exists-with-different-credential',
      ]) {
        auth.erreur = FirebaseAuthException(code: code);
        await expectLater(
          repo.signInWithApple(),
          throwsA(isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', code)),
        );
      }
      expect(requetes, isEmpty);
    });
  });

  group('revokeAppleSignInIfLinked', () {
    test('personne de connecté : rien', () async {
      await repo.revokeAppleSignInIfLinked();
      expect(auth.revoques, isEmpty);
    });

    test('compte e-mail + Google : aucune ré-authentification Apple',
        () async {
      final user = _FakeUser(fournisseurs: ['password', 'google.com']);
      auth.utilisateur = user;

      await repo.revokeAppleSignInIfLinked();

      expect(user.reauthentifications, isEmpty);
      expect(auth.revoques, isEmpty);
    });

    test('compte Apple : ré-authentification Apple puis révocation avec le '
        'code frais', () async {
      final user = _FakeUser(fournisseurs: ['apple.com'])
        ..codeReauth = 'code-frais';
      auth.utilisateur = user;

      await repo.revokeAppleSignInIfLinked();

      expect(user.reauthentifications.single, isA<AppleAuthProvider>());
      expect(
        (user.reauthentifications.single as AppleAuthProvider).scopes,
        isEmpty,
        reason: 'ni nom ni adresse à redemander pour une suppression',
      );
      expect(auth.revoques, ['code-frais']);
    });

    test('Apple lié à un compte Google : révoqué aussi', () async {
      final user = _FakeUser(fournisseurs: ['google.com', 'apple.com'])
        ..codeReauth = 'code-frais';
      auth.utilisateur = user;

      await repo.revokeAppleSignInIfLinked();

      expect(auth.revoques, ['code-frais']);
    });

    test('aucun code rendu : échec, aucune révocation tentée', () async {
      auth.utilisateur = _FakeUser(fournisseurs: ['apple.com']);

      await expectLater(
        repo.revokeAppleSignInIfLinked(),
        throwsA(kAuthAppleVerificationFailed),
      );
      expect(auth.revoques, isEmpty);
    });

    test('feuille fermée : l’annulation remonte telle quelle (silencieuse)',
        () async {
      auth.utilisateur = _FakeUser(fournisseurs: ['apple.com'])
        ..erreurReauth = FirebaseAuthException(code: 'canceled');

      final echec = await repo
          .revokeAppleSignInIfLinked()
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(mapAuthError(echec!).isSilent, isTrue);
    });

    test('autre identifiant Apple : message dédié conservé', () async {
      auth.utilisateur = _FakeUser(fournisseurs: ['apple.com'])
        ..erreurReauth = FirebaseAuthException(code: 'user-mismatch');

      final echec = await repo
          .revokeAppleSignInIfLinked()
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(mapAuthError(echec!).message, contains('Apple'));
    });

    test('credential refusé : jamais « mot de passe incorrect », mais « rien '
        'n’a été supprimé »', () async {
      auth.utilisateur = _FakeUser(fournisseurs: ['apple.com'])
        ..erreurReauth = FirebaseAuthException(code: 'invalid-credential');

      await expectLater(
        repo.revokeAppleSignInIfLinked(),
        throwsA(kAuthAppleVerificationFailed),
      );
    });

    test('révocation refusée par Firebase : même traduction', () async {
      auth
        ..utilisateur = (_FakeUser(fournisseurs: ['apple.com'])
          ..codeReauth = 'code-frais')
        ..erreurRevocation = FirebaseAuthException(code: 'invalid-credential');

      await expectLater(
        repo.revokeAppleSignInIfLinked(),
        throwsA(kAuthAppleVerificationFailed),
      );
    });
  });
}

UserCredential _cred(_FakeUser user, {required bool nouveau}) =>
    _FakeCred(user, AdditionalUserInfo(isNewUser: nouveau));

// ─── Doubles ────────────────────────────────────────────────────────────────

class _FakeAuth implements FirebaseAuth {
  AuthProvider? dernierFournisseur;
  UserCredential? reponse;
  Object? erreur;
  Object? erreurRevocation;
  User? utilisateur;
  final revoques = <String>[];

  @override
  User? get currentUser => utilisateur;

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) async {
    dernierFournisseur = provider;
    if (erreur != null) throw erreur!;
    utilisateur = reponse!.user;
    return reponse!;
  }

  @override
  Future<void> revokeTokenWithAuthorizationCode(String code) async {
    if (erreurRevocation != null) throw erreurRevocation!;
    revoques.add(code);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FirebaseAuth.${invocation.memberName}');
}

class _FakeUser implements User {
  _FakeUser({this.email, this.displayName, List<String> fournisseurs = const []})
      : providerData = [for (final f in fournisseurs) _FakeUserInfo(f)];

  @override
  final String uid = 'uid-apple-001';
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final bool emailVerified = true;
  // Apple ne fournit jamais de numéro : `/users/sync` doit s'en passer.
  @override
  final String? phoneNumber = null;
  @override
  final List<UserInfo> providerData;

  int rafraichissements = 0;
  bool echecRafraichissement = false;
  bool supprime = false;
  String? codeReauth;
  Object? erreurReauth;
  final reauthentifications = <AuthProvider>[];

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) {
      rafraichissements++;
      if (echecRafraichissement) {
        throw FirebaseAuthException(code: 'network-request-failed');
      }
    }
    return 'jeton';
  }

  @override
  Future<void> delete() async => supprime = true;

  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    reauthentifications.add(provider);
    if (erreurReauth != null) throw erreurReauth!;
    return _FakeCred(
      this,
      AdditionalUserInfo(isNewUser: false, authorizationCode: codeReauth),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('User.${invocation.memberName}');
}

class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('UserInfo.${invocation.memberName}');
}

class _FakeCred implements UserCredential {
  _FakeCred(this.user, this.additionalUserInfo);

  @override
  final User? user;
  @override
  final AdditionalUserInfo? additionalUserInfo;
  @override
  AuthCredential? get credential => null;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    required this.status,
    required this.body,
    required this.onRequest,
    this.erreurReseau = false,
  });

  final int status;
  final String body;
  final void Function(RequestOptions) onRequest;
  final bool erreurReseau;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    if (erreurReseau) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'injoignable',
      );
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

