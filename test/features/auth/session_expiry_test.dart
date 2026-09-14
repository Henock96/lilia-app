// R-06 — que se passe-t-il quand la session n'est plus valable ?
//
// Avant : rien. `AuthInterceptor` tentait **un** rafraîchissement du jeton sur
// 401 puis laissait l'erreur passer. `ApiErrorKind.unauthorized` était calculé
// par `ErrorInterceptor` et lu par deux dépôts pour des replis locaux, mais
// **personne ne traitait la session elle-même**. Un compte supprimé côté
// serveur, un jeton révoqué : le client restait « connecté » face à des écrans
// vides et des erreurs génériques, indéfiniment, sans un mot.
//
// Les pièges à éviter en corrigeant, et que ces tests verrouillent :
// boucle de déconnexion, déconnexions concurrentes, messages en double.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/application/auth_failure_announcer.dart';
import 'package:lilia_app/features/auth/application/session_guard.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

import 'fake_auth_repository.dart';

const _connecte = AppUser(uid: 'uid-1', email: 'cliente@lilia.cg');
const _erreur401 = ApiException(
  'Unauthorized',
  statusCode: 401,
  kind: ApiErrorKind.unauthorized,
);

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAuthRepository(user: _connecte);
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    container.read(authFailureAnnouncerProvider);
  });

  tearDown(() async {
    container.dispose();
    await repo.dispose();
  });

  SessionGuard garde() => container.read(sessionGuardProvider.notifier);

  AuthFailure? annonce() =>
      container.read(authFailureAnnouncerProvider)?.failure;

  test('un 401 déconnecte et annonce une session expirée', () async {
    await garde().handle(_erreur401);

    expect(repo.appelsSignOut, 1);
    expect(annonce()?.kind, AuthFailureKind.sessionExpired);
    expect(annonce()!.message.toLowerCase(), contains('session'));
  });

  test('pas de déconnexion sur une erreur qui n’est pas un 401', () async {
    await garde().handle(
      const ApiException('Service indisponible', kind: ApiErrorKind.server),
    );

    expect(repo.appelsSignOut, 0);
    expect(annonce(), isNull);
  });

  test('pas de déconnexion quand personne n’est connecté', () async {
    // Un 401 sur un appel public ne doit pas déclencher un nettoyage de
    // session inexistante — ni un message à un visiteur qui n'a rien demandé.
    repo.emitSession(null);

    await garde().handle(_erreur401);

    expect(repo.appelsSignOut, 0);
    expect(annonce(), isNull);
  });

  group('Pas de boucle, pas de doublon', () {
    test('deux 401 simultanés ne déconnectent qu’une fois', () async {
      // Plusieurs requêtes partent ensemble au démarrage d'un écran : elles
      // échouent toutes les trois avec le même 401.
      await Future.wait([
        garde().handle(_erreur401),
        garde().handle(_erreur401),
        garde().handle(_erreur401),
      ]);

      expect(repo.appelsSignOut, 1);
    });

    test('deux 401 simultanés ne produisent qu’un seul message', () async {
      var messages = 0;
      container.listen(authFailureAnnouncerProvider, (_, next) {
        if (next != null) messages++;
      });

      await Future.wait([garde().handle(_erreur401), garde().handle(_erreur401)]);

      expect(messages, 1);
    });

    test('un 401 arrivé après la déconnexion ne relance rien', () async {
      await garde().handle(_erreur401);
      repo.emitSession(null);

      await garde().handle(_erreur401);

      expect(repo.appelsSignOut, 1);
    });
  });

  test('une nouvelle session réarme la garde', () async {
    // Sinon, se reconnecter après une expiration laisserait le client sans
    // protection pour le reste de la vie du processus.
    await garde().handle(_erreur401);
    repo.emitSession(_connecte);

    await garde().handle(_erreur401);

    expect(repo.appelsSignOut, 2);
  });
}
