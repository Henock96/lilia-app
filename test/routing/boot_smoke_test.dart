// « 1402 tests verts sur un worker qui ne démarrait pas. »
//
// Les autres fichiers de routage éprouvent la décision (fonction pure), la
// table de routes (sans monter d'écran) et la pile (avec des écrans témoins).
// Aucun ne répond à la question la plus bête et la plus importante :
// **est-ce que l'application démarre ?**
//
// Ici, on monte le VRAI routeur, avec sa VRAIE table et ses VRAIS écrans, et on
// regarde si l'écran de connexion apparaît. C'est ce test qui aurait attrapé la
// mise en pause de Riverpod 3 — qui laissait l'application sur l'écran de
// démarrage, indéfiniment, sans qu'aucun test ni `flutter analyze` ne bronche.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/presentation/signin_page.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lilia_app/features/splash/presentation/splash_screen.dart';
import 'package:lilia_app/routing/app_router.dart';

import '../features/auth/fake_auth_repository.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

class _OnboardingAFaire extends OnboardingStatus {
  @override
  Future<bool> build() async => false;
}

void main() {
  late FakeAuthRepository repo;

  /// Monte l'application telle que `main.dart` la monte : le routeur est
  /// **observé** (`ref.watch`), pas seulement lu.
  Future<void> demarrer(
    WidgetTester tester, {
    required OnboardingStatus Function() onboarding,
  }) async {
    // Surface volontairement large.
    //
    // En test de widget, Flutter substitue une police dont chaque glyphe est
    // une boîte de largeur fixe : les textes y occupent bien plus de place
    // qu'à l'écran, et deux mises en page débordent sur le 800×600 par défaut
    // (le lien « pas de compte ? » de la connexion, la colonne de
    // l'onboarding). Ce sont des artefacts de la police de test, pas des
    // défauts d'affichage — mais ils feraient échouer un test qui ne parle
    // pas de mise en page.
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    repo = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        onboardingStatusProvider.overrideWith(onboarding),
        // Seule concession : Analytics et Sentry veulent un Firebase initialisé.
        routerObserversProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repo.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _App(),
      ),
    );
  }

  testWidgets('l’application démarre sur l’écran de démarrage', (tester) async {
    await demarrer(tester, onboarding: _OnboardingFait.new);
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('… puis en SORT, et atteint l’écran de connexion', (
    tester,
  ) async {
    // LE test. Sans lui, un écran de démarrage dont on ne sort jamais passe
    // pour un succès : `flutter analyze` est vert, tous les tests unitaires
    // sont verts, et l'application est un logo figé.
    await demarrer(tester, onboarding: _OnboardingFait.new);
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('premier lancement → onboarding, pas connexion', (tester) async {
    await demarrer(tester, onboarding: _OnboardingAFaire.new);

    // ⚠️ Pas de `pumpAndSettle` ici : `OnboardingScreen` fait tourner un
    // `AnimationController` en `repeat(reverse: true)`, l'arbre ne se
    // stabilise donc jamais et le test attendrait dix minutes avant d'échouer.
    // Même piège que le carrousel de bannières de l'accueil.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
  });
}

/// Réplique minimale de `MyApp` : ce qui compte est le `ref.watch` du routeur.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(routerProvider));
  }
}
