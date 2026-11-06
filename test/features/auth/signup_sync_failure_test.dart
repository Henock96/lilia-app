// Inscription par e-mail — le **vrai** `FirebaseAuthenticationRepository`.
//
// Une coupure pendant `/users/sync` ne dit pas si le compte a été créé : la
// réponse a pu se perdre après l'écriture en base. Supprimer le compte Firebase
// laissait alors une ligne Lilia sans compte et, `email` étant unique, cette
// adresse restait refusée pour toujours, par e-mail comme par Google.
//
// Comme dans `apple_auth_repository_test.dart`, seul Firebase est doublé : la
// chaîne `ApiClient` est la vraie, interceptors compris, car c'est elle qui
// décide du rejeu. Tout appel Firebase non prévu lève.

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

const _refusServeur = 'Cette adresse e-mail est déjà utilisée.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeUser user;
  late _FakeAuth auth;
  late _FauxServeur serveur;
  late FirebaseAuthenticationRepository repo;

  setUp(() {
    user = _FakeUser();
    auth = _FakeAuth(user);
    serveur = _FauxServeur();
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'jeton',
      forceRefreshToken: () async => 'jeton',
    );
    api.dio.httpClientAdapter = serveur;
    repo = FirebaseAuthenticationRepository(auth, GoogleSignIn.instance, api);
  });

  Future<void> inscrire() => repo.createUserWithEmailAndPassword(
        email: 'ada@example.com',
        password: 'motdepasse',
        name: 'Ada',
        phone: '061234567',
      );

  final inviteAConnexion = throwsA(
    isA<AuthFailure>()
        .having((f) => f.message, 'message', contains('vous connecter')),
  );

  group('issue inconnue', () {
    test('coupure : compte conservé, session fermée, invite à se connecter',
        () async {
      serveur.reponses = [DioExceptionType.connectionError];

      await expectLater(inscrire(), inviteAConnexion);

      expect(user.supprime, isFalse,
          reason: 'la ligne Lilia a peut-être été créée');
      expect(auth.deconnexions, 1);
    });

    test('délai dépassé : même traitement qu’une coupure', () async {
      serveur.reponses = [DioExceptionType.receiveTimeout];

      await expectLater(inscrire(), inviteAConnexion);

      expect(user.supprime, isFalse);
      expect(auth.deconnexions, 1);
    });

    test('réponse 5xx : même traitement, la ligne a pu être écrite', () async {
      serveur.reponses = [503];

      await expectLater(inscrire(), inviteAConnexion);

      expect(serveur.appels, 2, reason: 'un 5xx se rejoue une fois');
      expect(user.supprime, isFalse);
      expect(auth.deconnexions, 1);
    });

    test('fermeture de session en échec : l’invitation à se connecter reste',
        () async {
      serveur.reponses = [DioExceptionType.connectionError];
      auth.erreurDeconnexion = FirebaseAuthException(code: 'internal-error');

      await expectLater(inscrire(), inviteAConnexion);

      expect(user.supprime, isFalse);
    });

    test('coupure passagère : rejouée une fois, inscription aboutie', () async {
      serveur.reponses = [DioExceptionType.connectionError, 200];

      await expectLater(inscrire(), completes);

      expect(serveur.appels, 2);
      expect(user.supprime, isFalse);
      expect(auth.deconnexions, 0);
    });
  });

  group('refus du serveur', () {
    test('compte Firebase supprimé, message du serveur intact', () async {
      serveur.reponses = [409];

      await expectLater(
        inscrire(),
        throwsA(isA<AuthFailure>()
            .having((f) => f.message, 'message', _refusServeur)),
      );

      expect(user.supprime, isTrue,
          reason: 'le serveur a répondu : aucune ligne ne reste derrière');
      expect(serveur.appels, 1, reason: 'un refus ne se rejoue pas');
    });
  });
}

class _FakeAuth implements FirebaseAuth {
  _FakeAuth(this.utilisateur);

  final _FakeUser utilisateur;
  int deconnexions = 0;
  Object? erreurDeconnexion;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      _FakeCred(utilisateur);

  @override
  Future<void> signOut() async {
    if (erreurDeconnexion != null) throw erreurDeconnexion!;
    deconnexions++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FirebaseAuth.${invocation.memberName}');
}

class _FakeUser implements User {
  @override
  final String uid = 'uid-inscription-001';

  bool supprime = false;

  @override
  Future<void> updateDisplayName(String? displayName) async {}

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'jeton';

  @override
  Future<void> delete() async => supprime = true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('User.${invocation.memberName}');
}

class _FakeCred implements UserCredential {
  _FakeCred(this.user);

  @override
  final User? user;
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  @override
  AuthCredential? get credential => null;
}

/// Réponses successives de `/users/sync` : un statut HTTP, ou le type d'une
/// panne de transport. La dernière se répète.
class _FauxServeur implements HttpClientAdapter {
  List<Object> reponses = [200];
  int appels = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = appels < reponses.length ? appels : reponses.length - 1;
    appels++;
    final reponse = reponses[index];
    if (reponse is DioExceptionType) {
      throw DioException(requestOptions: options, type: reponse);
    }
    final statut = reponse as int;
    return ResponseBody.fromString(
      statut < 400
          ? '{"data":{"isNew":true}}'
          : '{"success":false,"message":"$_refusServeur"}',
      statut,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
