// B-02 / B-03 / M-02 — l'écran d'inscription.
//
// Trois défauts couverts ici :
//
// - **B-03** : un dialogue modal `barrierDismissible: false` était ouvert
//   depuis un `ref.listen` et refermé via un `BuildContext` mémorisé dans un
//   champ, affecté seulement à la frame suivante. Un échec plus rapide le
//   laissait ouvert pour toujours.
// - **B-02** : l'erreur de synchronisation backend était annoncée après que la
//   redirection eut démonté l'écran — donc jamais vue.
// - **M-02** : le bouton Google de cet écran était une copie de celui de la
//   connexion, et cette copie ne proposait pas la saisie du numéro.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/presentation/auth_failure_announcer_scope.dart';
import 'package:lilia_app/features/auth/presentation/phone_collection_sheet.dart';
import 'package:lilia_app/features/auth/presentation/signup_page.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';

import 'fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  /// L'écran d'inscription porte six champs : il dépasse la hauteur par défaut
  /// du banc de test (600 px), et un `tap` sur un bouton hors écran ne touche
  /// rien — silencieusement.
  void surfaceHaute(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpSignUp(
    WidgetTester tester, {
    AppUser? profil,
  }) async {
    surfaceHaute(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          if (profil != null)
            userProfileProvider.overrideWith((ref) async => profil),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              AuthFailureAnnouncerScope(child: child ?? const SizedBox()),
          home: const SignUpPage(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> remplirEtValider(WidgetTester tester) async {
    final champs = find.byType(TextFormField);
    await tester.enterText(champs.at(0), 'Amie Bakala');
    await tester.enterText(champs.at(1), '060000000');
    await tester.enterText(champs.at(2), 'amie@lilia.cg');
    await tester.enterText(champs.at(3), 'motdepasse');
    await tester.enterText(champs.at(4), 'motdepasse');
    await tester.tap(find.byKey(const Key('signup_submit')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('B-03 — aucun dialogue modal bloquant', () {
    testWidgets('le chargement vit dans le bouton, pas dans une modale',
        (tester) async {
      final porte = Completer<void>();
      repo.porte = porte;
      await pumpSignUp(tester);

      await remplirEtValider(tester);

      // Un `Dialog` modal aurait été poussé sur le Navigator.
      expect(find.byType(Dialog), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('signup_submit')))
            .onPressed,
        isNull,
        reason: 'le bouton doit être grisé pendant l’inscription',
      );

      porte.complete();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    });

    testWidgets('après un échec, le formulaire redevient utilisable',
        (tester) async {
      repo.signUpError = const ApiException(
        'Service indisponible.',
        statusCode: 503,
        kind: ApiErrorKind.server,
      );
      await pumpSignUp(tester);

      await remplirEtValider(tester);

      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('signup_submit')))
            .onPressed,
        isNotNull,
      );
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('B-02 — l’échec de synchronisation est visible', () {
    testWidgets('le message du serveur est affiché', (tester) async {
      repo.signUpError = const ApiException(
        'Service indisponible.',
        statusCode: 503,
        kind: ApiErrorKind.server,
      );
      await pumpSignUp(tester);

      await remplirEtValider(tester);

      expect(find.text('Service indisponible.'), findsOneWidget);
    });

    testWidgets('aucun préfixe technique dans le message', (tester) async {
      repo.signUpError = const ApiException(
        'peu importe',
        kind: ApiErrorKind.network,
      );
      await pumpSignUp(tester);

      await remplirEtValider(tester);

      expect(find.textContaining('réseau'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });

  group('M-02 — numéro de téléphone après Google', () {
    testWidgets('un compte Google sans numéro se voit proposer la saisie',
        (tester) async {
      // Le bouton Google est partagé avec l'écran de connexion : c'est ce
      // partage qui corrige M-02, où la copie de l'inscription n'appelait pas
      // `maybePromptPhoneNumber`.
      await pumpSignUp(tester, profil: const AppUser(uid: 'u1', phone: null));

      await tester.tap(find.byKey(const Key('signin_google')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(PhoneCollectionSheet), findsOneWidget);
    });

    testWidgets('un compte qui a déjà un numéro n’est pas dérangé',
        (tester) async {
      await pumpSignUp(
        tester,
        profil: const AppUser(uid: 'u1', phone: '060000000'),
      );

      await tester.tap(find.byKey(const Key('signin_google')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(PhoneCollectionSheet), findsNothing);
    });
  });

  testWidgets('le code de parrainage suit jusqu’au dépôt via Google',
      (tester) async {
    await pumpSignUp(tester, profil: const AppUser(uid: 'u1', phone: '06'));

    // Le champ « Code de parrainage » est le dernier du formulaire.
    await tester.enterText(find.byType(TextFormField).last, 'parrain8');
    await tester.pump();
    await tester.tap(find.byKey(const Key('signin_google')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(repo.dernierReferralCode, 'PARRAIN8');
  });
}
