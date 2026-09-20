// La matrice de navigation, cette fois avec un `Router` réellement monté.
//
// `redirect_matrix_test` éprouve la DÉCISION (fonction pure). Ce fichier
// éprouve ce que go_router en FAIT : la pile de navigation, le bouton retour,
// et l'enchaînement 401 → garde de session → phase → routeur.
//
// La table de routes est réduite à des écrans témoins. C'est délibéré : monter
// `HomeScreen` ferait partir quatre appels réseau, `CheckoutPage` en
// demanderait autant, et l'objet du test — la pile — disparaîtrait derrière le
// bruit. Les CHEMINS, eux, sont ceux de l'application, et
// `router_lifecycle_test` vérifie séparément que la vraie table les déclare.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/application/auth_failure_announcer.dart';
import 'package:lilia_app/features/auth/application/session_guard.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/routing/session_phase.dart';

import '../features/auth/fake_auth_repository.dart';

const _cliente = AppUser(uid: 'uid-1', email: 'cliente@lilia.cg');
const _erreur401 = ApiException(
  'Unauthorized',
  statusCode: 401,
  kind: ApiErrorKind.unauthorized,
);

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

/// Un écran témoin : son texte sert de sonde.
Widget _ecran(String nom) => Scaffold(body: Center(child: Text(nom)));

GoRouter _construireRouteur(ProviderContainer c) {
  final rafraichissement = ValueNotifier<SessionPhase>(
    c.read(sessionPhaseProvider),
  );
  c.listen<SessionPhase>(
    sessionPhaseProvider,
    (_, phase) => rafraichissement.value = phase,
    fireImmediately: true,
  );
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: rafraichissement,
    redirect: (context, state) => resolveRedirect(
      phase: c.read(sessionPhaseProvider),
      matchedLocation: state.matchedLocation,
      uri: state.uri,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => _ecran('Splash')),
      GoRoute(path: '/onboarding', builder: (_, _) => _ecran('Onboarding')),
      GoRoute(path: '/signin', builder: (_, _) => _ecran('SignIn')),
      GoRoute(path: '/signup', builder: (_, _) => _ecran('SignUp')),
      GoRoute(path: '/', builder: (_, _) => _ecran('Home')),
      GoRoute(path: '/cart', builder: (_, _) => _ecran('Cart')),
      GoRoute(
        path: '/commandes',
        builder: (_, _) => _ecran('Commandes'),
        routes: [
          GoRoute(
            path: ':orderId',
            builder: (_, s) => _ecran('Commande ${s.pathParameters['orderId']}'),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => _ecran('Profile'),
        routes: [
          GoRoute(path: 'favoris', builder: (_, _) => _ecran('Favoris')),
        ],
      ),
    ],
  );
}

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;
  late GoRouter routeur;

  Future<void> monter(WidgetTester tester, {AppUser? session}) async {
    repo = FakeAuthRepository(user: session);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        onboardingStatusProvider.overrideWith(_OnboardingFait.new),
      ],
    );
    container.read(authFailureAnnouncerProvider);
    routeur = _construireRouteur(container);
    addTearDown(() async {
      routeur.dispose();
      container.dispose();
      await repo.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: routeur),
      ),
    );
  }

  String emplacement() =>
      routeur.routerDelegate.currentConfiguration.uri.toString();

  group('démarrage', () {
    testWidgets('pendant le bootstrap, c’est l’écran de démarrage', (
      tester,
    ) async {
      await monter(tester);
      // Une seule frame : la session n'a pas encore été résolue.
      expect(find.text('Splash'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('SignIn'), findsNothing);
      await tester.pumpAndSettle();
    });

    /// Ce test disait l'inverse : « déconnecté → Login ». C'était le mur
    /// d'inscription — personne ne pouvait voir un vendeur ni un prix avant
    /// d'avoir créé un compte.
    ///
    /// Ce qu'il protégeait reste vrai et reste vérifié : l'accueil n'est monté
    /// qu'**après** la résolution de la session (U-03), jamais « en attendant ».
    /// C'est la destination de sortie qui a changé, pas le moment.
    testWidgets('déconnecté → ACCUEIL public, jamais le login', (
      tester,
    ) async {
      await monter(tester);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('SignIn'), findsNothing);
      expect(emplacement(), '/');
    });

    testWidgets('connecté → Accueil, sans passer par le login', (tester) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('SignIn'), findsNothing);
    });
  });

  group('routes protégées', () {
    testWidgets('sans session → Login', (tester) async {
      await monter(tester);
      await tester.pumpAndSettle();
      routeur.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('SignIn'), findsOneWidget);
      expect(emplacement(), '/signin?from=%2Fprofile');
    });

    testWidgets('avec session → la page demandée', (tester) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      routeur.go('/profile/favoris');
      await tester.pumpAndSettle();
      expect(find.text('Favoris'), findsOneWidget);
    });
  });

  group('R-05 — restauration de la destination', () {
    testWidgets('login depuis une route protégée y ramène', (tester) async {
      await monter(tester);
      await tester.pumpAndSettle();

      routeur.go('/commandes/abc');
      await tester.pumpAndSettle();
      expect(find.text('SignIn'), findsOneWidget);
      expect(emplacement(), '/signin?from=%2Fcommandes%2Fabc');

      repo.emitSession(_cliente); // connexion réussie
      await tester.pumpAndSettle();

      expect(find.text('Commande abc'), findsOneWidget);
      expect(emplacement(), '/commandes/abc');
    });

    testWidgets('login sans destination mène à l’accueil', (tester) async {
      await monter(tester);
      await tester.pumpAndSettle();
      // Le visiteur est sur l'accueil ; il ouvre la connexion de lui-même,
      // sans destination à restaurer.
      routeur.go('/signin');
      await tester.pumpAndSettle();
      expect(emplacement(), '/signin');

      repo.emitSession(_cliente);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('une destination demandée avant le bootstrap survit', (
      tester,
    ) async {
      // Le parcours exact de `notification_service._handleNotificationData` :
      // une notification tapée alors que l'application était tuée fait
      // `router.push('/commandes/xyz')` AVANT que Firebase ait résolu la
      // session. C'est le scénario que R-05 cite en exemple, et `push` (et non
      // `go`) est bien ce que fait ce code-là.
      await monter(tester, session: _cliente);
      routeur.push('/commandes/xyz');
      await tester.pumpAndSettle();
      expect(find.text('Commande xyz'), findsOneWidget);
    });

    testWidgets(
      'notification + session expirée → la commande s’ouvre après login',
      () {
        return (WidgetTester tester) async {
          // Le cas complet décrit par l'audit : le client tape « votre commande
          // est en route », sa session a expiré, il se connecte… et atterrissait
          // sur l'accueil. La commande était perdue.
          await monter(tester);
          // `go` et non `push` : hors session ouverte, c'est ce que fait
          // désormais `notification_service`. Un `push` perdrait le `from` en
          // route — voir le test suivant, qui verrouille cette raison.
          routeur.go('/commandes/xyz');
          await tester.pumpAndSettle();
          expect(find.text('SignIn'), findsOneWidget);

          repo.emitSession(_cliente);
          await tester.pumpAndSettle();
          expect(find.text('Commande xyz'), findsOneWidget);
        };
      }(),
    );
  });

  group('pourquoi `go` et non `push` hors session', () {
    testWidgets('un `push` perd le `from` à la réévaluation', (tester) async {
      // Ce test ne décrit pas un souhait, il constate une contrainte de
      // go_router : une entrée empilée par `push`, redirigée puis réévaluée
      // au changement de phase, retombe sur `/signin` **sans** son paramètre.
      // C'est la raison pour laquelle `notification_service` bascule sur `go`
      // quand la session n'est pas ouverte. Si un jour ce test se met à
      // échouer, c'est que go_router a corrigé la chose — et que la
      // distinction peut disparaître.
      await monter(tester);
      routeur.push('/commandes/xyz');
      await tester.pumpAndSettle();

      repo.emitSession(_cliente);
      await tester.pumpAndSettle();

      expect(find.text('Commande xyz'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('déconnexion', () {
    testWidgets('depuis Profil → Login', (tester) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      routeur.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);

      await container.read(authControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(find.text('SignIn'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('le retour ne ramène pas sur une page protégée', (
      tester,
    ) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      routeur.go('/profile');
      await tester.pumpAndSettle();
      routeur.push('/profile/favoris');
      await tester.pumpAndSettle();
      expect(find.text('Favoris'), findsOneWidget);

      await container.read(authControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(find.text('SignIn'), findsOneWidget);

      // La pile doit être vide : rien à dépiler vers l'arrière.
      expect(routeur.routerDelegate.canPop(), isFalse);

      // Et le retour système ne doit pas davantage y ramener.
      final retourTraite = await routeur.routerDelegate.popRoute();
      await tester.pumpAndSettle();
      expect(retourTraite, isFalse, reason: 'plus rien à dépiler');
      expect(find.text('Favoris'), findsNothing);
      expect(find.text('Profile'), findsNothing);
      expect(find.text('SignIn'), findsOneWidget);
    });
  });

  group('session expirée (401)', () {
    testWidgets('un 401 sur une page protégée mène au login', (tester) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      routeur.go('/profile');
      await tester.pumpAndSettle();

      await container.read(sessionGuardProvider.notifier).handle(_erreur401);
      await tester.pumpAndSettle();

      expect(find.text('SignIn'), findsOneWidget);
      expect(
        container.read(authFailureAnnouncerProvider)?.failure.kind,
        AuthFailureKind.sessionExpired,
      );
    });

    testWidgets('la destination est gardée, et restaurée après reconnexion', (
      tester,
    ) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      routeur.go('/profile');
      await tester.pumpAndSettle();

      await container.read(sessionGuardProvider.notifier).handle(_erreur401);
      await tester.pumpAndSettle();
      expect(emplacement(), '/signin?from=%2Fprofile');

      repo.emitSession(_cliente);
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('trois 401 simultanés → une seule déconnexion, un message', (
      tester,
    ) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      routeur.go('/commandes');
      await tester.pumpAndSettle();
      final avant = repo.appelsSignOut;

      final garde = container.read(sessionGuardProvider.notifier);
      await Future.wait([
        garde.handle(_erreur401),
        garde.handle(_erreur401),
        garde.handle(_erreur401),
      ]);
      await tester.pumpAndSettle();

      expect(repo.appelsSignOut - avant, 1);
      expect(container.read(authFailureAnnouncerProvider)?.id, 1);
      expect(find.text('SignIn'), findsOneWidget);
    });

    testWidgets('aucune boucle : le routeur se stabilise sur le login', (
      tester,
    ) async {
      await monter(tester, session: _cliente);
      await tester.pumpAndSettle();
      routeur.go('/profile');
      await tester.pumpAndSettle();

      await container.read(sessionGuardProvider.notifier).handle(_erreur401);
      // `pumpAndSettle` lève de lui-même si l'arbre ne se stabilise jamais —
      // c'est précisément ce que produirait une boucle de redirection.
      await tester.pumpAndSettle();
      final stable = emplacement();
      await tester.pumpAndSettle();
      expect(emplacement(), stable);
    });
  });
}
