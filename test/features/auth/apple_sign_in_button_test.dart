// Sign in with Apple — le bouton, sur les deux écrans d'authentification.
//
// Ces tests montent les **vrais** écrans au-dessus du **vrai**
// `SignInController` ; seul le dépôt est doublé. Ils fixent :
//
//  - la frontière de plateforme : le bouton n'existe que sur iOS ;
//  - l'exclusion mutuelle avec Google et l'e-mail (deux flux concurrents
//    s'annulent) ;
//  - l'annulation silencieuse, l'échec lisible ;
//  - le parrainage et la saisie du numéro, hérités du chemin Google ;
//  - l'apparence exigée par Apple (noir en clair, blanc en sombre).

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/presentation/auth_failure_announcer_scope.dart';
import 'package:lilia_app/features/auth/presentation/phone_collection_sheet.dart';
import 'package:lilia_app/features/auth/presentation/signin_page.dart';
import 'package:lilia_app/features/auth/presentation/signup_page.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';

import 'fake_auth_repository.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

const _apple = Key('signin_apple');
const _google = Key('signin_google');

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  Future<void> pumpEcran(
    WidgetTester tester,
    Widget ecran, {
    AppUser? profil,
    Brightness luminosite = Brightness.light,
  }) async {
    // Les deux écrans dépassent la hauteur par défaut du banc (600 px) : un
    // `tap` hors écran ne touche rien, silencieusement.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          if (profil != null)
            userProfileProvider.overrideWith((ref) async => profil),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: luminosite),
          builder: (context, child) =>
              AuthFailureAnnouncerScope(child: child ?? const SizedBox()),
          home: ecran,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> laisserTourner(WidgetTester tester) async {
    // Pas de `pumpAndSettle` : des animations tournent en boucle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  bool actif(WidgetTester tester, Key cle) {
    final w = tester.widget(find.byKey(cle));
    if (w is ButtonStyleButton) return w.onPressed != null;
    throw StateError('pas un bouton : $w');
  }

  group('frontière de plateforme', () {
    testWidgets('Android : aucun bouton Apple, ni à la connexion ni à '
        'l’inscription', (tester) async {
      await pumpEcran(tester, const SignInPage());
      expect(find.byKey(_apple), findsNothing);
      expect(find.byKey(_google), findsOneWidget);

      await pumpEcran(tester, const SignUpPage());
      expect(find.byKey(_apple), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS : bouton présent sur les deux écrans, à côté de Google',
        (tester) async {
      await pumpEcran(tester, const SignInPage());
      expect(find.byKey(_apple), findsOneWidget);
      expect(find.text('Continuer avec Apple'), findsOneWidget);
      expect(find.byKey(_google), findsOneWidget);

      await pumpEcran(tester, const SignUpPage());
      expect(find.byKey(_apple), findsOneWidget);
    }, variant: _ios);
  });

  group('accessibilité et apparence', () {
    testWidgets('annoncé comme un bouton, sous son libellé, logo muet',
        (tester) async {
      final semantique = tester.ensureSemantics();
      await pumpEcran(tester, const SignInPage());

      expect(
        tester.getSemantics(find.byKey(_apple)),
        matchesSemantics(
          label: 'Continuer avec Apple',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      semantique.dispose();
    }, variant: _ios);

    Color fond(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.byKey(_apple))
        .style!
        .backgroundColor!
        .resolve(<WidgetState>{})!;

    testWidgets('thème clair : fond noir', (tester) async {
      await pumpEcran(tester, const SignInPage());
      expect(fond(tester), Colors.black);
    }, variant: _ios);

    testWidgets('thème sombre : fond blanc', (tester) async {
      await pumpEcran(tester, const SignInPage(), luminosite: Brightness.dark);
      expect(fond(tester), Colors.white);
    }, variant: _ios);
  });

  group('exclusion mutuelle des flux', () {
    testWidgets('pendant Apple : indicateur dans Apple, Google et e-mail '
        'grisés', (tester) async {
      repo.porte = Completer<void>();
      await pumpEcran(tester, const SignInPage());

      await tester.tap(find.byKey(_apple));
      await tester.pump();

      expect(actif(tester, _apple), isFalse);
      expect(actif(tester, _google), isFalse);
      expect(actif(tester, const Key('signin_submit')), isFalse);
      expect(
        find.descendant(
          of: find.byKey(_apple),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_google),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
        reason: 'seul le bouton touché rend compte de son travail',
      );

      repo.porte!.complete();
      await laisserTourner(tester);
    }, variant: _ios);

    testWidgets('pendant Google : Apple grisé, sans indicateur',
        (tester) async {
      repo.porte = Completer<void>();
      await pumpEcran(tester, const SignInPage());

      await tester.tap(find.byKey(_google));
      await tester.pump();

      expect(actif(tester, _apple), isFalse);
      expect(
        find.descendant(
          of: find.byKey(_apple),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      repo.porte!.complete();
      await laisserTourner(tester);
    }, variant: _ios);

    testWidgets('double tap : un seul flux Apple', (tester) async {
      repo.porte = Completer<void>();
      await pumpEcran(tester, const SignInPage());

      await tester.tap(find.byKey(_apple));
      await tester.tap(find.byKey(_apple), warnIfMissed: false);
      await tester.pump();

      expect(repo.appelsApple, 1);
      repo.porte!.complete();
      await laisserTourner(tester);
    }, variant: _ios);
  });

  group('issues', () {
    testWidgets('feuille Apple fermée : aucun message, bouton de nouveau '
        'utilisable', (tester) async {
      repo.appleError = FirebaseAuthException(
        code: 'canceled',
        message: 'The user canceled the authorization attempt.',
      );
      await pumpEcran(tester, const SignInPage());

      await tester.tap(find.byKey(_apple));
      await laisserTourner(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('canceled'), findsNothing);
      expect(actif(tester, _apple), isTrue);
      expect(find.byType(SignInPage), findsOneWidget);
    }, variant: _ios);

    testWidgets('échec Apple : message français, jamais le texte de '
        'plateforme', (tester) async {
      repo.appleError = FirebaseAuthException(
        code: 'failed',
        message: 'The authorization attempt failed.',
      );
      await pumpEcran(tester, const SignInPage());

      await tester.tap(find.byKey(_apple));
      await laisserTourner(tester);

      expect(find.textContaining('La connexion avec Apple'), findsOneWidget);
      expect(find.textContaining('authorization'), findsNothing);
      expect(actif(tester, _apple), isTrue);
    }, variant: _ios);

    testWidgets('succès sans numéro : la saisie est proposée (passable)',
        (tester) async {
      await pumpEcran(
        tester,
        const SignInPage(),
        profil: const AppUser(uid: 'uid-apple', phone: null),
      );

      await tester.tap(find.byKey(_apple));
      await laisserTourner(tester);

      expect(find.byType(PhoneCollectionSheet), findsOneWidget);
    }, variant: _ios);

    testWidgets('succès avec numéro : rien n’est demandé', (tester) async {
      await pumpEcran(
        tester,
        const SignInPage(),
        profil: const AppUser(uid: 'uid-apple', phone: '060000000'),
      );

      await tester.tap(find.byKey(_apple));
      await laisserTourner(tester);

      expect(find.byType(PhoneCollectionSheet), findsNothing);
    }, variant: _ios);
  });

  testWidgets('inscription : le code de parrainage suit jusqu’au dépôt via '
      'Apple', (tester) async {
    await pumpEcran(
      tester,
      const SignUpPage(),
      profil: const AppUser(uid: 'uid-apple', phone: '06'),
    );

    // Le champ « Code de parrainage » est le dernier du formulaire.
    await tester.enterText(find.byType(TextFormField).last, 'parrain8');
    await tester.pump();
    await tester.tap(find.byKey(_apple));
    await laisserTourner(tester);

    expect(repo.appelsApple, 1);
    expect(repo.dernierReferralCode, 'PARRAIN8');
  }, variant: _ios);
}
