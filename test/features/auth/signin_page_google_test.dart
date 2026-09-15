// T-03 — l'écran de connexion face à une annulation Google.
//
// Le défaut corrigé, tel qu'un client le vivait : il touche « Se connecter avec
// Google », voit la liste de ses comptes, change d'avis, ferme la feuille — et
// l'application lui répond
//
//     GoogleSignInException(code GoogleSignInExceptionCode.canceled, null, null)
//
// dans un bandeau rouge. En anglais, avec le nom de la classe et celui de la
// valeur d'énumération.
//
// Ces tests montent le **vrai** écran au-dessus du **vrai** contrôleur ; seul
// le dépôt est doublé.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/presentation/auth_failure_announcer_scope.dart';
import 'package:lilia_app/features/auth/presentation/signin_page.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

import 'fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  Future<void> pumpSignIn(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          // Reproduit le montage de `main.dart` : l'afficheur d'échecs vit
          // au-dessus du routeur, pas dans l'écran.
          builder: (context, child) =>
              AuthFailureAnnouncerScope(child: child ?? const SizedBox()),
          home: const SignInPage(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapGoogle(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('signin_google')));
    // Pas de `pumpAndSettle` : plusieurs animations de l'application tournent
    // en boucle et l'arbre ne se stabiliserait jamais.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// `onPressed == null` signifie « bouton grisé ».
  bool googleActif(WidgetTester tester) =>
      tester
          .widget<OutlinedButton>(find.byKey(const Key('signin_google')))
          .onPressed !=
      null;

  group('T-03 — annulation', () {
    testWidgets('aucun message n’est affiché', (tester) async {
      repo.googleError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      await pumpSignIn(tester);

      await tapGoogle(tester);

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('aucun texte technique nulle part dans l’arbre',
        (tester) async {
      repo.googleError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      await pumpSignIn(tester);

      await tapGoogle(tester);

      for (final motif in const [
        'GoogleSignInException',
        'Exception',
        'canceled',
        'firebase_auth/',
        'null',
      ]) {
        expect(
          find.textContaining(motif, findRichText: true),
          findsNothing,
          reason: '« $motif » ne doit pas apparaître à l’écran',
        );
      }
    });

    testWidgets('le bouton redevient utilisable', (tester) async {
      repo.googleError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      await pumpSignIn(tester);

      await tapGoogle(tester);

      expect(googleActif(tester), isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('l’écran de connexion est toujours là', (tester) async {
      repo.googleError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      await pumpSignIn(tester);

      await tapGoogle(tester);

      expect(find.byKey(const Key('signin_email')), findsOneWidget);
      expect(find.byKey(const Key('signin_submit')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Échec réel — le client doit être prévenu', () {
    testWidgets('panne réseau → message français, sans préfixe technique',
        (tester) async {
      repo.googleError = const ApiException(
        'peu importe',
        kind: ApiErrorKind.network,
      );
      await pumpSignIn(tester);

      await tapGoogle(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('réseau'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('le bouton redevient utilisable après l’échec', (tester) async {
      repo.googleError = const ApiException(
        'peu importe',
        kind: ApiErrorKind.network,
      );
      await pumpSignIn(tester);

      await tapGoogle(tester);

      expect(googleActif(tester), isTrue);
    });
  });

  group('M-01 — pendant l’opération', () {
    testWidgets('le bouton est grisé et montre un indicateur', (tester) async {
      // La porte retient l'appel : sans elle, l'opération se résoudrait avant
      // le premier `pump` et l'état « en cours » ne serait jamais observable.
      final porte = Completer<void>();
      repo.porte = porte;
      await pumpSignIn(tester);

      await tester.tap(find.byKey(const Key('signin_google')));
      await tester.pump();

      expect(googleActif(tester), isFalse,
          reason: 'un second appui ne doit pas pouvoir partir');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      porte.complete();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(repo.appelsGoogle, 1);
    });

    testWidgets('le bouton e-mail est grisé lui aussi', (tester) async {
      // Les deux boutons partagent le même contrôleur : lancer Google ne doit
      // pas laisser partir une connexion par mot de passe en parallèle.
      final porte = Completer<void>();
      repo.porte = porte;
      await pumpSignIn(tester);

      await tester.tap(find.byKey(const Key('signin_google')));
      await tester.pump();

      final bouton = tester.widget<ElevatedButton>(
        find.byKey(const Key('signin_submit')),
      );
      expect(bouton.onPressed, isNull);

      porte.complete();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
