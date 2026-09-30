// P3-18 — un visiteur qui tape « Commandes » ou « Profil » reste dans la
// coque (barre d'onglets visible), lit ce que l'onglet contient, et peut
// joindre le support ou « À propos » sans compte. L'écran réel de l'onglet
// n'est jamais construit sans session, et la règle d'accès du routeur ne
// change pas (`guest_mode_test`, `protected_locations_test`).
//
// Coque réelle (`BottomNavigationPage`) et garde réel (`resolveRedirect`) ;
// les écrans des onglets sont des témoins, comme dans `guest_mode_test`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/presentation/guest_tab_prompt.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/home/presentation/bottom_navigation_bar.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/features/user/presentation/pages/about_page.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/routing/session_phase.dart';
import 'package:lilia_app/theme/app_theme.dart';

import '../features/auth/fake_auth_repository.dart';

const _cliente = AppUser(uid: 'uid-1', email: 'cliente@lilia.cg');

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

class _PanierVide extends CartController {
  @override
  Future<Cart?> build() async => null;
}

/// Compte les constructions de l'écran réel : il ne doit jamais l'être sans
/// session (il interrogerait des routes authentifiées).
int constructionsCommandes = 0;

class _EcranCommandesReel extends StatelessWidget {
  const _EcranCommandesReel();
  @override
  Widget build(BuildContext context) {
    constructionsCommandes++;
    return const Scaffold(body: Center(child: Text('Liste des commandes')));
  }
}

Widget _ecran(String nom) => Scaffold(body: Center(child: Text(nom)));

GoRouter _routeur(ProviderContainer c) {
  final rafraichissement = ValueNotifier<SessionPhase>(
    c.read(sessionPhaseProvider),
  );
  c.listen<SessionPhase>(
    sessionPhaseProvider,
    (_, phase) => rafraichissement.value = phase,
    fireImmediately: true,
  );
  return GoRouter(
    initialLocation: '/',
    refreshListenable: rafraichissement,

    redirect: (context, state) => resolveRedirect(
      phase: c.read(sessionPhaseProvider),
      matchedLocation: state.matchedLocation,
      uri: state.uri,
    ),
    routes: [
      // Le bootstrap passe par `/splash` (`resolveRedirect`) : sans cette
      // route, go_router montrait son écran d'erreur le temps d'une frame.
      GoRoute(path: '/splash', builder: (_, _) => _ecran('Démarrage')),
      GoRoute(path: '/signin', builder: (_, _) => _ecran('SignIn')),
      GoRoute(path: '/signup', builder: (_, _) => _ecran('SignUp')),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => BottomNavigationPage(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => _ecran('Accueil'))],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cart', builder: (_, _) => _ecran('Mon panier')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/commandes',
                builder: (_, _) => const _EcranCommandesReel(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) =>
                        _ecran('Détail ${s.pathParameters['id']}'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => _ecran('Profil réel'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;
  late GoRouter routeur;

  setUp(() => constructionsCommandes = 0);

  Future<void> monter(
    WidgetTester tester, {
    AppUser? session,
    ThemeData? theme,
    double textScale = 1,
  }) async {
    repo = FakeAuthRepository(user: session);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        onboardingStatusProvider.overrideWith(_OnboardingFait.new),
        cartControllerProvider.overrideWith(_PanierVide.new),
      ],
    );
    routeur = _routeur(container);
    addTearDown(() async {
      routeur.dispose();
      container.dispose();
      await repo.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: routeur,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String emplacement() =>
      routeur.routerDelegate.currentConfiguration.uri.toString();

  Future<void> onglet(WidgetTester tester, String libelle) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(libelle),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('invité → Commandes : l’onglet s’ouvre dans la coque', (
    tester,
  ) async {
    await monter(tester);
    await onglet(tester, 'Commandes');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Mes commandes'), findsOneWidget);
    expect(find.byKey(const Key('guest_tab_sign_in')), findsOneWidget);
    expect(find.text('SignIn'), findsNothing);
    expect(constructionsCommandes, 0);
    final barre = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(barre.selectedIndex, 2);
  });

  testWidgets('invité → Profil : support et « À propos » joignables', (
    tester,
  ) async {
    await monter(tester);
    await onglet(tester, 'Profil');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Écrire au support'), findsOneWidget);
    expect(find.text('Appeler le support'), findsOneWidget);

    await tester.ensureVisible(find.text('À propos de Lilia Food'));
    await tester.tap(find.text('À propos de Lilia Food'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('SignIn'), findsNothing);
  });

  testWidgets('« Se connecter » ramène sur l’onglet, avec l’écran réel', (
    tester,
  ) async {
    await monter(tester);
    await onglet(tester, 'Commandes');

    await tester.tap(find.byKey(const Key('guest_tab_sign_in')));
    await tester.pumpAndSettle();
    expect(emplacement(), '/signin?from=%2Fcommandes');

    repo.emitSession(_cliente);
    await tester.pumpAndSettle();
    expect(emplacement(), '/commandes');
    expect(find.text('Liste des commandes'), findsOneWidget);
    expect(constructionsCommandes, greaterThan(0));
  });

  testWidgets('connecté : l’écran réel, sans invitation', (tester) async {
    await monter(tester, session: _cliente);
    await onglet(tester, 'Commandes');

    expect(find.text('Liste des commandes'), findsOneWidget);
    expect(find.byKey(const Key('guest_tab_sign_in')), findsNothing);
  });

  testWidgets('la règle d’accès est intacte : /commandes exige un compte', (
    tester,
  ) async {
    await monter(tester);
    routeur.go('/commandes');
    await tester.pumpAndSettle();

    expect(emplacement(), '/signin?from=%2Fcommandes');
    expect(constructionsCommandes, 0);
  });

  testWidgets(
    'retour Android / Accueil : l’invitation se referme, sans perte',
    (tester) async {
      await monter(tester);
      routeur.go('/cart');
      await tester.pumpAndSettle();
      await onglet(tester, 'Profil');
      expect(find.text('Mon profil'), findsOneWidget);

      // Retour système : on retrouve l'onglet recouvert, pas la sortie.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Mon profil'), findsNothing);
      expect(find.text('Mon panier'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await onglet(tester, 'Commandes');
      await onglet(tester, 'Accueil');
      expect(find.text('Accueil'), findsWidgets);
      expect(find.byKey(const Key('guest_tab_sign_in')), findsNothing);
    },
  );

  testWidgets('« Créer un compte » ramène aussi sur l’onglet', (tester) async {
    await monter(tester);
    await onglet(tester, 'Commandes');

    await tester.ensureVisible(find.byKey(const Key('guest_tab_sign_up')));
    await tester.tap(find.byKey(const Key('guest_tab_sign_up')));
    await tester.pumpAndSettle();
    expect(emplacement(), '/signup?from=%2Fcommandes');

    repo.emitSession(_cliente);
    await tester.pumpAndSettle();
    expect(emplacement(), '/commandes');
    expect(find.text('Liste des commandes'), findsOneWidget);
  });

  testWidgets('trois bénéfices réels par onglet', (tester) async {
    await monter(tester);
    await onglet(tester, 'Commandes');
    for (final t in [
      'Suivez la préparation puis la livraison',
      'Retrouvez votre historique et recommandez en un geste',
      'Signalez un problème après la remise',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(
      tester.widgetList(find.byType(GuestTabPrompt)).single,
      isA<GuestTabPrompt>().having((p) => p.benefits.length, 'bénéfices', 3),
    );

    await onglet(tester, 'Profil');
    for (final t in [
      'Vos adresses de livraison enregistrées',
      'Vos plats et boutiques favoris',
      'Des points de fidélité, et le parrainage de vos proches',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
  });

  for (final (nom, theme) in [
    ('clair', AppTheme.light),
    ('sombre', AppTheme.dark),
  ]) {
    for (final echelle in [1.0, 2.0]) {
      testWidgets(
        'invitations, thème $nom, texte ×$echelle : aucun débordement',
        (tester) async {
          await monter(tester, theme: theme, textScale: echelle);
          await onglet(tester, 'Commandes');
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const Key('guest_tab_sign_up')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await onglet(tester, 'Profil');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
