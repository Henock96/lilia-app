// A-01 — un `GoRouter` par application, et une table de routes cohérente.
//
// Ces tests construisent le VRAI routeur (vraie table, vraies routes) sans
// monter d'écran : les `pageBuilder` ne s'exécutent qu'à l'affichage. On peut
// donc éprouver la déclaration des routes et le cycle de vie du routeur sans
// réseau, sans Firebase et sans Google Maps.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/routing/session_phase.dart';

import '../features/auth/fake_auth_repository.dart';

const _cliente = AppUser(uid: 'uid-1', email: 'cliente@lilia.cg');

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAuthRepository(user: _cliente);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        onboardingStatusProvider.overrideWith(_OnboardingFait.new),
        // Firebase Analytics et Sentry ne sont pas initialisés en test
        // unitaire, et ce n'est pas eux qu'on éprouve ici.
        routerObserversProvider.overrideWithValue(const []),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await repo.dispose();
  });

  /// Lit le routeur **en s'y abonnant**, comme le fait `MyApp`.
  ///
  /// ⚠️ Un simple `container.read` ne suffit pas : Riverpod 3 met en pause un
  /// provider que personne n'écoute, et la pause se propage jusqu'au flux
  /// Firebase — la phase resterait à `bootstrapping` pour toujours. Ce détour
  /// n'est pas une commodité de test, c'est la reproduction fidèle de ce que
  /// fait `ref.watch(routerProvider)` dans l'arbre de widgets.
  GoRouter routeurEcoute() {
    container.listen(routerProvider, (_, _) {}, fireImmediately: true);
    return container.read(routerProvider);
  }

  Future<void> pomper() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('cycle de vie', () {
    test(
      'le routeur n’est PAS recréé quand la session change (A-01)',
      () async {
        final routeur = routeurEcoute();
        await pomper();

        // Le scénario complet d'une session : résolution, déconnexion,
        // reconnexion. C'étaient 3 à 4 instances de `GoRouter` auparavant,
        // chacune emportant la pile de navigation avec elle.
        repo.emitSession(null);
        await pomper();
        expect(identical(container.read(routerProvider), routeur), isTrue);

        repo.emitSession(_cliente);
        await pomper();
        expect(identical(container.read(routerProvider), routeur), isTrue);

        repo.emitSession(null);
        await pomper();
        expect(
          identical(container.read(routerProvider), routeur),
          isTrue,
          reason: 'une seule instance doit survivre à toute la session',
        );
      },
    );

    test('le routeur suit bien la phase malgré tout', () async {
      // Contre-épreuve du test précédent : ne pas se reconstruire ne doit pas
      // vouloir dire ne pas réagir.
      //
      // C'est ce test qui a mis au jour la mise en pause de Riverpod 3 :
      // lu sans être écouté, le routeur laisse la phase à `bootstrapping`
      // indéfiniment. La leçon vaut au-delà du test — c'est la différence
      // entre « le provider se construit » et « l'application démarre ».
      routeurEcoute();
      await pomper();
      expect(container.read(sessionPhaseProvider), SessionPhase.authenticated);

      repo.emitSession(null);
      await pomper();
      expect(
        container.read(sessionPhaseProvider),
        SessionPhase.unauthenticated,
      );
    });

    test('la destruction du conteneur libère le routeur', () async {
      final routeur = routeurEcoute();
      await pomper();
      container.dispose();
      // `GoRouter.dispose()` est idempotent-hostile : un second appel lève.
      // Que celui-ci lève prouve que `ref.onDispose(router.dispose)` a bien
      // été exécuté — sans lui, aucune instance n'était jamais libérée.
      expect(routeur.dispose, throwsA(anything));
      // Le conteneur est déjà détruit ; neutraliser le tearDown.
      container = ProviderContainer();
    });
  });

  group('smoke de la table de routes', () {
    late GoRouter routeur;

    setUp(() {
      routeur = routeurEcoute();
    });

    test('chaque valeur de AppRoutes est déclarée et localisable', () {
      // Détecte une route déclarée dans l'enum mais absente du routeur, et
      // inversement un nom mal orthographié : `namedLocation` lève dans les
      // deux cas.
      const parametres = <AppRoutes, Map<String, String>>{
        AppRoutes.restaurantDetail: {'id': '12'},
        // La fiche produit est adressable depuis la correction P2-006 : elle
        // porte son identifiant dans le CHEMIN, et ne dépend plus d'un objet
        // passé en `extra` — qui ne survit pas à une mort de processus.
        AppRoutes.productDetail: {'productId': 'prod-1'},
        // Les quatre dernières routes de P2-006, adressables à leur tour :
        // menu, fiche favorite, avis et rédaction d'avis ne dépendent plus
        // d'un objet passé en `extra`.
        AppRoutes.menuDetail: {'menuId': 'menu-1'},
        AppRoutes.favoriteDetail: {'productId': 'prod-1'},
        AppRoutes.reviews: {'restaurantId': 'resto-1'},
        AppRoutes.writeReview: {'restaurantId': 'resto-1'},
        AppRoutes.orderDetail: {'orderId': 'abc'},
        AppRoutes.orderTracking: {'orderId': 'abc'},
        AppRoutes.paymentPending: {'paymentId': 'pay-1'},
        // F3-06
        AppRoutes.claimForm: {'orderId': 'abc'},
        AppRoutes.claimDetail: {'claimId': 'claim-1'},
      };

      for (final route in AppRoutes.values) {
        expect(
          () => routeur.namedLocation(
            route.routeName,
            pathParameters: parametres[route] ?? const {},
          ),
          returnsNormally,
          reason: '${route.name} n’est pas déclarée dans le routeur',
        );
      }
    });

    test('les emplacements essentiels sont ceux qu’on croit', () {
      String pour(AppRoutes r, [Map<String, String> p = const {}]) =>
          routeur.namedLocation(r.routeName, pathParameters: p);

      expect(pour(AppRoutes.splash), '/splash');
      expect(pour(AppRoutes.signIn), '/signin');
      expect(pour(AppRoutes.home), '/');
      expect(pour(AppRoutes.cart), '/cart');
      expect(pour(AppRoutes.checkout), '/cart/delivery-options/checkout');
      expect(pour(AppRoutes.commandes), '/commandes');
      expect(pour(AppRoutes.profile), '/profile');
      expect(pour(AppRoutes.favoris), '/profile/favoris');
      expect(pour(AppRoutes.draftOrders), '/profile/draft-orders');
      // Les cinq écrans qui vivaient hors du routeur.
      expect(pour(AppRoutes.notifications), '/notifications');
      expect(pour(AppRoutes.editProfile), '/profile/edit');
      expect(pour(AppRoutes.about), '/profile/about');
      expect(
        pour(AppRoutes.writeReview, {'restaurantId': 'resto-1'}),
        '/reviews/resto-1/write',
      );
      expect(
        pour(AppRoutes.menuDetail, {'menuId': 'menu-1'}),
        '/menu/menu-1',
      );
      expect(
        pour(AppRoutes.favoriteDetail, {'productId': 'prod-1'}),
        '/profile/favoris/details/prod-1',
      );
      expect(
        pour(AppRoutes.orderTracking, {'orderId': 'abc'}),
        '/commandes/abc/tracking',
      );
    });

    test('R-02 — le chemin du détail de commande est réparé', () {
      // Valait `'/:orderId'` dans l'enum : un chemin qui n'existait nulle part,
      // pendant que le routeur en déclarait un autre en dur juste à côté.
      expect(AppRoutes.orderDetail.path, ':orderId');
      expect(
        routeur.namedLocation(
          AppRoutes.orderDetail.routeName,
          pathParameters: {'orderId': 'abc'},
        ),
        '/commandes/abc',
      );
    });

    test('aucun nom de route n’est dupliqué', () {
      final noms = AppRoutes.values.map((r) => r.routeName).toList();
      expect(noms.toSet().length, noms.length);
    });

    test('les sous-routes ne commencent jamais par « / »', () {
      // Convention du fichier d'enum. go_router 17 tolère la faute par
      // concaténation de segments, ce qui la rend invisible — jusqu'au jour où
      // quelqu'un lit la valeur et croit tenir un chemin absolu.
      const racines = {
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.home,
        AppRoutes.signIn,
        AppRoutes.signUp,
        AppRoutes.commandes,
        AppRoutes.profile,
        AppRoutes.cart,
        AppRoutes.orderSuccess,
        AppRoutes.reviews,
      };
      for (final route in AppRoutes.values) {
        expect(
          route.path.startsWith('/'),
          racines.contains(route),
          reason: '${route.name} → ${route.path}',
        );
      }
    });

    test('l’écran de démarrage est le point d’entrée', () {
      expect(
        routeur.routeInformationProvider.value.uri.path,
        AppRoutes.splash.path,
      );
    });
  });
}
