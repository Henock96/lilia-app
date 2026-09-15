// RF-03 / B-08 / B-09 — les opérations de mot de passe ne touchent plus à la
// session.
//
// `AuthController.build()` rend un `Stream<AppUser?>` : son état **signifie**
// « qui est connecté ». Trois méthodes y écrivaient pourtant
// `AsyncValue.data(null)` en guise de « opération terminée » —
// `updatePassword`, `sendPasswordResetEmail` et sa variante. Conséquence
// reproductible : Profil → changer le mot de passe → « Modifier le profil »
// affichait « Utilisateur non trouvé », parce qu'`edit_profile_page` lit
// `ref.watch(authControllerProvider).value`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/application/auth_failure_announcer.dart';
import 'package:lilia_app/features/auth/application/password_controller.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

import 'fake_auth_repository.dart';

const _connecte = AppUser(uid: 'uid-1', email: 'cliente@lilia.cg');

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

  /// Amorce le flux de session et laisse la première valeur arriver.
  Future<AppUser?> session() async {
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    return container.read(authControllerProvider).value;
  }

  group('B-08 — la session survit aux opérations de mot de passe', () {
    test('changement réussi : l’utilisateur est toujours là', () async {
      expect(await session(), isNotNull);

      await container
          .read(passwordControllerProvider.notifier)
          .updatePassword('nouveau-mot-de-passe');

      expect(
        container.read(authControllerProvider).value,
        isNotNull,
        reason: 'c’est ce null qui affichait « Utilisateur non trouvé »',
      );
    });

    test('changement échoué : l’utilisateur est toujours là', () async {
      await session();
      repo.passwordError = FirebaseAuthException(code: 'weak-password');

      await container
          .read(passwordControllerProvider.notifier)
          .updatePassword('123');

      expect(container.read(authControllerProvider).value, isNotNull);
      expect(container.read(authControllerProvider).hasError, isFalse);
    });

    test('réinitialisation par e-mail : la session n’est pas touchée',
        () async {
      await session();

      await container
          .read(passwordControllerProvider.notifier)
          .sendPasswordResetEmailTo('cliente@lilia.cg');

      expect(container.read(authControllerProvider).value, isNotNull);
    });
  });

  group('B-09 — messages du changement de mot de passe', () {
    test('mot de passe trop simple → message métier, pas le code Firebase',
        () async {
      repo.passwordError = FirebaseAuthException(
        code: 'weak-password',
        message: 'Password should be at least 6 characters',
      );

      final echec = await container
          .read(passwordControllerProvider.notifier)
          .updatePassword('123');

      expect(echec, isNotNull);
      expect(echec!.kind, AuthFailureKind.weakPassword);
      expect(echec.message, isNot(contains('Password should')));
      expect(echec.message, isNot(contains('firebase_auth/')));
    });

    test('session trop ancienne → invite à se reconnecter', () async {
      repo.passwordError = FirebaseAuthException(code: 'requires-recent-login');

      final echec = await container
          .read(passwordControllerProvider.notifier)
          .updatePassword('nouveau-mot-de-passe');

      expect(echec!.kind, AuthFailureKind.requiresRecentLogin);
      expect(echec.message.toLowerCase(), contains('reconnectez'));
    });

    test('panne réseau → message réseau', () async {
      repo.passwordError = FirebaseAuthException(
        code: 'network-request-failed',
      );

      final echec = await container
          .read(passwordControllerProvider.notifier)
          .updatePassword('nouveau-mot-de-passe');

      expect(echec!.kind, AuthFailureKind.network);
    });

    test('succès → aucun échec rendu', () async {
      final echec = await container
          .read(passwordControllerProvider.notifier)
          .updatePassword('nouveau-mot-de-passe');

      expect(echec, isNull);
    });
  });

  group('États de chargement', () {
    test('le chargement se termine après un échec', () async {
      repo.passwordError = FirebaseAuthException(code: 'weak-password');

      await container
          .read(passwordControllerProvider.notifier)
          .updatePassword('123');

      expect(container.read(passwordControllerProvider).isLoading, isFalse);
    });

    test('un second appel pendant le premier est ignoré', () async {
      final notifier = container.read(passwordControllerProvider.notifier);

      await Future.wait([
        notifier.updatePassword('nouveau-mot-de-passe'),
        notifier.updatePassword('nouveau-mot-de-passe'),
      ]);

      expect(container.read(passwordControllerProvider).isLoading, isFalse);
    });
  });
}
