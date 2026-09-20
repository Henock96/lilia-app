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
import 'package:lilia_app/features/home/presentation/bottom_navigation_bar.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
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

  /// ⚠️ Pas de `pumpAndSettle` une fois l'accueil monté : son carrousel de
  /// bannières s'auto-défile, l'arbre ne se stabilise donc **jamais** et le
  /// test attendrait dix minutes avant d'échouer. On pompe sur un budget borné.
  ///
  /// Les exceptions sont **drainées** à chaque frame : l'accueil pose une
  /// bannière en asset local (`assets/images/banner.png`), que le bundle d'un
  /// test de widget ne sert pas. C'est un artefact de l'environnement de test,
  /// sans rapport avec ce qui est éprouvé ici — la destination du routeur. Ne
  /// pas le drainer ferait échouer le test sur une image absente.
  Future<void> laisserRouter(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      tester.takeException();
      if (find.byType(SplashScreen).evaluate().isEmpty && i > 4) break;
    }
    // Quelques frames de plus une fois l'accueil monté, pour que ses providers
    // aient rendu leur premier état.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      tester.takeException();
    }
  }

  /// Démonte l'arbre et laisse retomber les minuteurs de l'accueil.
  ///
  /// Le chatoiement des images en cours de chargement (`AppShimmerBox`) et le
  /// carrousel de bannières posent des minuteurs à usage unique. Le binding de
  /// test refuse de rendre la main tant qu'il en reste un — « A Timer is still
  /// pending even after the widget tree was disposed ». On démonte, puis on
  /// laisse passer assez de temps simulé pour qu'ils tirent dans le vide.
  Future<void> ranger(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    tester.takeException();
  }

  testWidgets('l’application démarre sur l’écran de démarrage', (tester) async {
    await demarrer(tester, onboarding: _OnboardingFait.new);
    expect(find.byType(SplashScreen), findsOneWidget);
    await laisserRouter(tester);
    await ranger(tester);
  });

  testWidgets('… puis en SORT, et atteint l’ACCUEIL sans compte', (
    tester,
  ) async {
    // LE test. Sans lui, un écran de démarrage dont on ne sort jamais passe
    // pour un succès : `flutter analyze` est vert, tous les tests unitaires
    // sont verts, et l'application est un logo figé.
    //
    // Il disait auparavant « atteint l'écran de connexion » : c'était le mur
    // d'inscription. L'accueil est désormais public, et c'est précisément ce
    // que ce test doit protéger — une régression du garde le renverrait sur
    // `/signin` sans que rien d'autre ne s'en aperçoive.
    await demarrer(tester, onboarding: _OnboardingFait.new);
    await laisserRouter(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(SignInPage), findsNothing);
    expect(find.byType(BottomNavigationPage), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    await ranger(tester);
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
