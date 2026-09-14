// T-02 (bout en bout) et T-04 — le contrôleur des opérations d'ouverture de
// session.
//
// Ces tests font tourner le **vrai** `SignInController` au-dessus d'un dépôt
// double. Ils fixent trois contrats que rien ne garantissait :
//
//  1. une annulation Google ne produit **aucun** message ;
//  2. tout autre échec produit un message français, jamais l'objet technique ;
//  3. un échec de `/users/sync` à l'inscription est déposé dans un canal qui
//     **survit au démontage** de l'écran d'inscription (B-02).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/application/auth_failure_announcer.dart';
import 'package:lilia_app/features/auth/application/sign_in_controller.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

import 'fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    // Le canal d'annonce est `keepAlive` : il doit exister avant les opérations
    // pour retenir ce qui y est déposé.
    container.read(authFailureAnnouncerProvider);
  });

  tearDown(() async {
    container.dispose();
    await repo.dispose();
  });

  AuthFailure? annonce() =>
      container.read(authFailureAnnouncerProvider)?.failure;

  group('T-02 — annulation Google', () {
    test('n’annonce rien du tout', () async {
      repo.googleError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle();

      expect(annonce(), isNull, reason: 'une annulation n’est pas une erreur');
    });

    test('termine le chargement — le bouton doit redevenir utilisable',
        () async {
      repo.googleError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle();

      expect(container.read(signInControllerProvider).isLoading, isFalse);
    });

    test('l’échec rendu est traduit, jamais l’exception Google brute',
        () async {
      repo.googleError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      final echec = await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle();

      expect(echec, isA<AuthFailure>());
      expect(echec, isNot(isA<GoogleSignInException>()));
      expect('$echec', isNot(contains('GoogleSignInException')));
      // Et l'état, lui, est revenu au repos : il ne conserve aucune erreur.
      expect(container.read(signInControllerProvider).operation, isNull);
    });
  });

  group('Google — échecs réels', () {
    test('panne backend → message réseau annoncé', () async {
      repo.googleError = const ApiException(
        'peu importe',
        kind: ApiErrorKind.network,
      );

      await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle();

      expect(annonce()?.kind, AuthFailureKind.network);
      expect(annonce()!.message.toLowerCase(), contains('réseau'));
    });

    test('aucun préfixe technique dans le message annoncé', () async {
      repo.googleError = Exception('Erreur réseau: serveur injoignable');

      await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle();

      expect(annonce(), isNotNull);
      expect(annonce()!.message, isNot(contains('Exception')));
    });

    test('succès : le code de parrainage suit jusqu’au dépôt', () async {
      await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle(referralCode: 'PARRAIN8');

      expect(repo.dernierReferralCode, 'PARRAIN8');
      expect(annonce(), isNull);
    });

    test('M-01 — un second appel pendant le premier est ignoré', () async {
      final notifier = container.read(signInControllerProvider.notifier);

      await Future.wait([
        notifier.signInWithGoogle(),
        notifier.signInWithGoogle(),
      ]);

      expect(repo.appelsGoogle, 1,
          reason: 'un double tap ne doit ouvrir qu’un seul flux Google');
    });
  });

  group('Connexion e-mail', () {
    test('mot de passe incorrect → message neutre', () async {
      repo.signInError = FirebaseAuthException(code: 'wrong-password');

      await container
          .read(signInControllerProvider.notifier)
          .signInWithEmail('a@b.cg', 'x');

      expect(annonce()?.kind, AuthFailureKind.badCredentials);
      expect(annonce()!.message, isNot(contains('firebase_auth/')));
    });

    test('panne réseau → message réseau, pas « erreur inconnue »', () async {
      repo.signInError = FirebaseAuthException(code: 'network-request-failed');

      await container
          .read(signInControllerProvider.notifier)
          .signInWithEmail('a@b.cg', 'x');

      expect(annonce()?.kind, AuthFailureKind.network);
    });
  });

  group('T-04 — inscription : échec de la synchronisation backend', () {
    test('l’échec est annoncé, et pas seulement posé dans l’état', () async {
      repo.signUpError = const ApiException(
        'Adresse déjà enregistrée.',
        statusCode: 409,
        kind: ApiErrorKind.client,
      );

      await container.read(signInControllerProvider.notifier).signUpWithEmail(
            email: 'a@b.cg',
            password: 'motdepasse',
            name: 'Amie',
            phone: '060000000',
          );

      expect(annonce(), isNotNull);
      expect(annonce()!.message, 'Adresse déjà enregistrée.');
    });

    /// Le cœur de B-02. `SignUpPage` est démontée par la redirection avant que
    /// l'erreur n'arrive : si le message vit dans l'état d'un contrôleur lié à
    /// cette page, il disparaît avec elle. Le canal d'annonce est `keepAlive`,
    /// donc n'importe quel écran peut encore le lire ensuite.
    test('l’annonce survit à la disparition de l’écran d’inscription',
        () async {
      repo.signUpError = const ApiException(
        'Service indisponible.',
        statusCode: 503,
        kind: ApiErrorKind.server,
      );

      await container.read(signInControllerProvider.notifier).signUpWithEmail(
            email: 'a@b.cg',
            password: 'motdepasse',
            name: 'Amie',
            phone: '060000000',
          );

      // L'écran d'inscription disparaît : son contrôleur est détruit.
      container.invalidate(signInControllerProvider);

      expect(annonce()?.message, 'Service indisponible.');
    });

    test('le chargement se termine dans tous les cas', () async {
      repo.signUpError = FirebaseAuthException(code: 'email-already-in-use');

      await container.read(signInControllerProvider.notifier).signUpWithEmail(
            email: 'a@b.cg',
            password: 'motdepasse',
            name: 'Amie',
            phone: '060000000',
          );

      expect(container.read(signInControllerProvider).isLoading, isFalse);
    });

    test('inscription réussie : rien n’est annoncé', () async {
      await container.read(signInControllerProvider.notifier).signUpWithEmail(
            email: 'a@b.cg',
            password: 'motdepasse',
            name: 'Amie',
            phone: '060000000',
            referralCode: 'PARRAIN8',
          );

      expect(annonce(), isNull);
      expect(repo.dernierReferralCode, 'PARRAIN8');
    });
  });

  group('Canal d’annonce', () {
    test('deux échecs identiques successifs notifient deux fois', () async {
      // Sans identifiant incrémental, le second `AuthFailure` serait égal au
      // premier et `ref.listen` ne se déclencherait pas : le client taperait
      // deux fois et ne verrait qu'un message.
      final annonceur = container.read(authFailureAnnouncerProvider.notifier);
      const echec = AuthFailure(AuthFailureKind.network, 'Réseau.');

      annonceur.announce(echec);
      final premier = container.read(authFailureAnnouncerProvider);
      annonceur.announce(echec);
      final second = container.read(authFailureAnnouncerProvider);

      expect(second, isNot(premier));
      expect(second!.id, greaterThan(premier!.id));
    });

    test('une annulation n’est jamais mise dans le canal', () {
      container
          .read(authFailureAnnouncerProvider.notifier)
          .announce(kAuthCancelled);

      expect(container.read(authFailureAnnouncerProvider), isNull);
    });
  });
}
