// **Le retour système, mesuré au lieu d'être supposé.**
//
// L'audit signalait un risque en confiance LOW : le `PopScope` de la coque
// pose `canPop: currentIndex == 0`, et on ne pouvait pas trancher par la
// lecture s'il intercepte le retour **avant** que le navigateur imbriqué de
// l'onglet ait eu l'occasion de dépiler. Si c'était le cas, revenir depuis
// `/commandes/<id>` ramènerait à l'accueil au lieu de la liste des commandes.
//
// Ce fichier répond à la question. Il ne change aucun comportement : il
// constate celui qui existe, et fige la réponse pour que la prochaine
// modification de la coque ne l'emporte pas en silence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/features/commandes/presentation/commande_detail_page.dart';
import 'package:lilia_app/features/commandes/presentation/commande_page.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/home/presentation/search_screen.dart';
import 'package:lilia_app/features/splash/presentation/splash_screen.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/utils/provider_cache.dart';

import '../features/auth/fake_auth_repository.dart';

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

void main() {
  late GoRouter routeur;

  /// ⚠️ Pas de `pumpAndSettle` : le carrousel de l'accueil s'auto-défile,
  /// l'arbre ne se stabilise jamais. Les exceptions sont drainées — les
  /// images en asset ne sont pas servies dans un bundle de test.
  Future<void> avancer(WidgetTester tester, [int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      tester.takeException();
      if (i > 6 && find.byType(SplashScreen).evaluate().isEmpty && frames > 20) {
        break;
      }
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      tester.takeException();
    }
  }

  Future<void> demarrer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: const AppUser(uid: 'uid-a')),
        ),
        onboardingStatusProvider.overrideWith(_OnboardingFait.new),
        routerObserversProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    // ⚠️ `listen`, pas `read`. Riverpod 3 met en pause un provider que
    // personne n'écoute, et la pause se propage : `sessionPhase` reste à
    // `bootstrapping` et l'application ne quitte jamais `/splash`. C'est la
    // même précaution que `router_lifecycle_test` et `boot_smoke_test` — en
    // production, `MyApp` fait `ref.watch(routerProvider)`.
    addTearDown(container.listen(routerProvider, (_, _) {}).close);
    routeur = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: routeur),
      ),
    );
    await avancer(tester, 40);
  }

  /// Le retour système Android, tel que le `Router` le reçoit.
  Future<void> retourSysteme(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await avancer(tester);
  }

  /// Démonte et laisse retomber les minuteurs de l'accueil.
  Future<void> ranger(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(kCatalogCacheTtl);
    tester.takeException();
  }

  String emplacement() =>
      routeur.routerDelegate.currentConfiguration.uri.toString();

  testWidgets(
    'depuis une sous-route d’un onglet, le retour DÉPILE (il ne saute pas à l’accueil)',
    (tester) async {
      await demarrer(tester);
      expect(emplacement(), '/');

      routeur.go('/commandes');
      await avancer(tester);
      routeur.push('/commandes/cmd-1');
      await avancer(tester);
      // On observe l'ÉCRAN, pas l'URI : une route poussée par-dessus une
      // branche est un `ImperativeRouteMatch`, et `currentConfiguration.uri`
      // continue d'annoncer l'emplacement de la branche. La sonde mesurerait
      // alors autre chose que ce que le client voit.
      expect(find.byType(OrderDetailPage), findsOneWidget);

      await retourSysteme(tester);

      expect(
        find.byType(OrderDetailPage),
        findsNothing,
        reason: 'le retour doit dépiler le détail',
      );
      expect(
        find.byType(CommandePage),
        findsOneWidget,
        reason:
            'c’était le risque signalé : si le `PopScope` de la coque '
            'interceptait avant le navigateur de branche, on se retrouverait '
            'sur l’accueil et le client perdrait sa place',
      );
      expect(find.byType(HomeScreen), findsNothing);

      await ranger(tester);
    },
  );

  testWidgets(
    'à la RACINE d’un onglet secondaire, le retour ramène à l’accueil',
    (tester) async {
      await demarrer(tester);

      routeur.go('/commandes');
      await avancer(tester);
      expect(emplacement(), '/commandes');

      await retourSysteme(tester);

      expect(
        emplacement(),
        '/',
        reason:
            'sans le `PopScope` de la coque, le retour fermait l’application '
            'depuis n’importe quel onglet : une racine de branche n’a rien à '
            'dépiler',
      );

      await ranger(tester);
    },
  );

  testWidgets('depuis une sous-route de l’ACCUEIL, le retour dépile', (
    tester,
  ) async {
    await demarrer(tester);

    routeur.push('/search');
    await avancer(tester);
    expect(find.byType(SearchScreen), findsOneWidget);

    await retourSysteme(tester);

    expect(find.byType(SearchScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);

    await ranger(tester);
  });
}
