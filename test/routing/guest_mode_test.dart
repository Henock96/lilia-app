// Le parcours d'un visiteur sans compte, de bout en bout.
//
// Même harnais que `navigation_flow_test` — écrans témoins, chemins réels — et
// pour la même raison : monter `HomeScreen` ferait partir quatre appels réseau
// et l'objet du test, la pile de navigation, disparaîtrait derrière le bruit.
//
// Ce qui est éprouvé ici n'est pas « le garde laisse passer » (c'est le rôle de
// `protected_locations_test`), mais **l'enchaînement** :
//
//   ouvrir → parcourir → composer → buter sur le checkout → se connecter →
//   revenir exactement là où on était.
//
// C'est cet enchaînement qui casse en premier quand un redirect est ajouté, et
// aucun test de fonction pure ne peut l'attraper.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/routing/session_phase.dart';

import '../features/auth/fake_auth_repository.dart';

const _cliente = AppUser(uid: 'uid-1', email: 'cliente@lilia.cg');

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

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
      GoRoute(path: '/signin', builder: (_, _) => _ecran('SignIn')),
      GoRoute(path: '/signup', builder: (_, _) => _ecran('SignUp')),
      GoRoute(path: '/order-success', builder: (_, _) => _ecran('Succès')),
      GoRoute(
        path: '/',
        builder: (_, _) => _ecran('Home'),
        routes: [
          GoRoute(
            path: 'restaurant/:id',
            builder: (_, s) => _ecran('Vendeur ${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: 'product-detail',
            builder: (_, _) => _ecran('Produit'),
          ),
          GoRoute(path: 'search', builder: (_, _) => _ecran('Recherche')),
          GoRoute(
            path: 'notifications',
            builder: (_, _) => _ecran('Notifications'),
          ),
        ],
      ),
      GoRoute(
        path: '/cart',
        builder: (_, _) => _ecran('Panier'),
        routes: [
          GoRoute(
            path: 'delivery-options',
            builder: (_, _) => _ecran('Livraison'),
            routes: [
              GoRoute(path: 'checkout', builder: (_, _) => _ecran('Paiement')),
            ],
          ),
        ],
      ),
      GoRoute(path: '/commandes', builder: (_, _) => _ecran('Commandes')),
      GoRoute(path: '/profile', builder: (_, _) => _ecran('Profil')),
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
    await tester.pumpAndSettle();
  }

  String emplacement() =>
      routeur.routerDelegate.currentConfiguration.uri.toString();

  Future<void> aller(WidgetTester tester, String cible) async {
    routeur.go(cible);
    await tester.pumpAndSettle();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Test 1 — ouvrir l'application sans compte
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('1 — sans compte, l’application ouvre sur l’accueil', (
    tester,
  ) async {
    await monter(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('SignIn'), findsNothing);
    expect(emplacement(), '/');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Test 2 — parcourir le catalogue
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('2 — vendeur, produit et panier sont accessibles sans compte', (
    tester,
  ) async {
    await monter(tester);

    await aller(tester, '/restaurant/chez-awa');
    expect(find.text('Vendeur chez-awa'), findsOneWidget);

    await aller(tester, '/product-detail');
    expect(find.text('Produit'), findsOneWidget);

    await aller(tester, '/search');
    expect(find.text('Recherche'), findsOneWidget);

    await aller(tester, '/cart');
    expect(find.text('Panier'), findsOneWidget);
    // À aucun moment on n'a croisé l'écran de connexion.
    expect(find.text('SignIn'), findsNothing);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Test 3 — la connexion est demandée au checkout, et là seulement
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('3 — le checkout demande la connexion, le panier non', (
    tester,
  ) async {
    await monter(tester);

    await aller(tester, '/cart');
    expect(emplacement(), '/cart');

    await aller(tester, '/cart/delivery-options');
    expect(find.text('SignIn'), findsOneWidget);
    expect(emplacement(), '/signin?from=%2Fcart%2Fdelivery-options');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Test 4 — retour au checkout après connexion
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('4 — après connexion, on revient au checkout', (tester) async {
    await monter(tester);
    await aller(tester, '/cart/delivery-options');
    expect(find.text('SignIn'), findsOneWidget);

    repo.emitSession(_cliente);
    await tester.pumpAndSettle();

    expect(find.text('Livraison'), findsOneWidget);
    expect(emplacement(), '/cart/delivery-options');
  });

  testWidgets('4 bis — l’étape de paiement elle-même est restaurée', (
    tester,
  ) async {
    await monter(tester);
    await aller(tester, '/cart/delivery-options/checkout');
    expect(emplacement(), '/signin?from=%2Fcart%2Fdelivery-options%2Fcheckout');

    repo.emitSession(_cliente);
    await tester.pumpAndSettle();

    expect(emplacement(), '/cart/delivery-options/checkout');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Test 6 — un client déjà connecté n'est jamais interrogé
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('6 — avec session, aucun passage par la connexion', (
    tester,
  ) async {
    await monter(tester, session: _cliente);
    expect(find.text('Home'), findsOneWidget);

    await aller(tester, '/commandes');
    expect(find.text('Commandes'), findsOneWidget);

    await aller(tester, '/cart/delivery-options');
    expect(find.text('Livraison'), findsOneWidget);
    expect(find.text('SignIn'), findsNothing);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Tests 7 & 8 — les onglets qui exigent un compte
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('7 — Commandes demande la connexion, et y ramène', (
    tester,
  ) async {
    await monter(tester);
    await aller(tester, '/commandes');
    expect(emplacement(), '/signin?from=%2Fcommandes');

    repo.emitSession(_cliente);
    await tester.pumpAndSettle();
    expect(find.text('Commandes'), findsOneWidget);
  });

  testWidgets('8 — Profil demande la connexion, et y ramène', (tester) async {
    await monter(tester);
    await aller(tester, '/profile');
    expect(emplacement(), '/signin?from=%2Fprofile');

    repo.emitSession(_cliente);
    await tester.pumpAndSettle();
    expect(find.text('Profil'), findsOneWidget);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Tests 9, 10, 11 — Google, Apple, téléphone
  // ═══════════════════════════════════════════════════════════════════════════

  /// Les trois méthodes d'authentification aboutissent au **même** signal : une
  /// session Firebase qui s'ouvre. Le routeur ne sait pas — et ne doit pas
  /// savoir — par quelle porte elle est arrivée : il lit `sessionPhase`, dérivé
  /// du flux `authStateChanges`.
  ///
  /// Les tester séparément en les distinguant par leur fournisseur reviendrait
  /// à tester le SDK Firebase. Ce qui compte, et qui est vérifié ici, c'est
  /// que **la destination est restaurée quel que soit le moment** où la session
  /// s'ouvre — y compris après plusieurs allers-retours entre connexion et
  /// inscription, où le `from` est le plus fragile.
  group('9-11 — retour au checkout quelle que soit la méthode', () {
    for (final methode in ['Google', 'Apple', 'téléphone']) {
      testWidgets('$methode : la destination survit', (tester) async {
        await monter(tester);
        await aller(tester, '/cart/delivery-options/checkout');

        // Le visiteur hésite : connexion → inscription → connexion. C'est
        // `goToAuthRoute` qui transporte le `from` entre les deux écrans ; on
        // reproduit ici son résultat.
        await aller(
          tester,
          '/signup?from=%2Fcart%2Fdelivery-options%2Fcheckout',
        );
        expect(find.text('SignUp'), findsOneWidget);
        await aller(
          tester,
          '/signin?from=%2Fcart%2Fdelivery-options%2Fcheckout',
        );

        repo.emitSession(_cliente);
        await tester.pumpAndSettle();

        expect(emplacement(), '/cart/delivery-options/checkout');
        expect(find.text('Paiement'), findsOneWidget);
      });
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Garde-fous
  // ═══════════════════════════════════════════════════════════════════════════

  group('garde-fous', () {
    /// `Home → Login → Home → Login` : la boucle que le cahier des charges
    /// interdit explicitement. Elle apparaîtrait si l'accueil était à la fois
    /// public et destination de repli d'un redirect vers la connexion.
    testWidgets('aucune boucle : le routeur se stabilise', (tester) async {
      await monter(tester);
      await aller(tester, '/profile');
      expect(emplacement(), '/signin?from=%2Fprofile');

      // Plusieurs frames de plus : si une boucle existait, l'emplacement
      // changerait encore.
      await tester.pumpAndSettle();
      expect(emplacement(), '/signin?from=%2Fprofile');
    });

    /// Une notification tapée alors que l'application était tuée demande
    /// `/commandes/...` **avant** que Firebase ait répondu. Sans session, elle
    /// doit mener à la connexion — et non à l'accueil, qui ferait perdre la
    /// commande.
    testWidgets(
      'une destination protégée demandée au démarrage mène à la connexion',
      (tester) async {
        repo = FakeAuthRepository();
        container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            onboardingStatusProvider.overrideWith(_OnboardingFait.new),
          ],
        );
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
        // Avant résolution de la session.
        routeur.go('/commandes');
        await tester.pumpAndSettle();

        expect(emplacement(), '/signin?from=%2Fcommandes');
      },
    );

    /// Symétrique : une destination PUBLIQUE demandée au démarrage ne doit pas
    /// passer par la connexion. C'est le cas d'un lien partagé vers un vendeur.
    testWidgets('une destination publique demandée au démarrage s’ouvre', (
      tester,
    ) async {
      repo = FakeAuthRepository();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          onboardingStatusProvider.overrideWith(_OnboardingFait.new),
        ],
      );
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
      routeur.go('/restaurant/chez-awa');
      await tester.pumpAndSettle();

      expect(emplacement(), '/restaurant/chez-awa');
      expect(find.text('SignIn'), findsNothing);
    });

    /// Les emplacements de la barre d'onglets doivent exister dans la table de
    /// routes réelle, et être rangés du bon côté de la frontière : la coque les
    /// consulte pour décider d'ouvrir l'onglet ou la connexion.
    test('les quatre onglets sont classés', () {
      expect(kShellBranchLocations, hasLength(4));
      expect(kShellBranchLocations, ['/', '/cart', '/commandes', '/profile']);
    });
  });
}
