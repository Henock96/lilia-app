import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:lilia_app/features/cart/presentation/cart_screen.dart';
import 'package:lilia_app/features/commandes/presentation/checkout_page.dart';
import 'package:lilia_app/features/payments/presentation/payment_pending_args.dart';
import 'package:lilia_app/features/payments/presentation/payment_pending_page.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/commandes/presentation/commande_page.dart';
import 'package:lilia_app/features/commandes/presentation/fullscreen_tracking_screen.dart';
import 'package:lilia_app/features/commandes/presentation/order_success_page.dart';
import 'package:lilia_app/features/favoris/presentation/favoris_detail_page.dart';
import 'package:lilia_app/features/favoris/presentation/favoris_page.dart';
import 'package:lilia_app/features/home/presentation/bottom_navigation_bar.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/notifications/presentation/notifications_history_screen.dart';
import 'package:lilia_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lilia_app/features/splash/presentation/splash_screen.dart';
import 'package:lilia_app/features/user/edit_profile_page.dart';
import 'package:lilia_app/features/user/presentation/pages/about_page.dart';
import 'package:lilia_app/features/user/user_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/features/address/presentation/pages/address_page.dart';
import 'package:lilia_app/features/user/presentation/pages/change_password_page.dart';
import 'package:lilia_app/features/auth/presentation/signin_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/commandes/presentation/commande_detail_page.dart';
import '../features/home/presentation/not_found_page.dart';
import '../features/home/presentation/menu_detail_page.dart';
import '../features/home/presentation/product_detail_page.dart';
import '../features/home/presentation/restaurant_detail_screen.dart';
import '../features/home/presentation/search_screen.dart';
import '../features/reviews/presentation/screens/reviews_screen.dart';
import '../features/reviews/presentation/screens/write_review_screen.dart';
import '../features/cart/presentation/draft_orders_screen.dart';
import '../models/menu.dart';
import '../models/produit.dart';
import 'app_route_enum.dart';
import 'pending_destination.dart';
import 'protected_locations.dart';
import 'session_phase.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

part 'app_router.g.dart';

final _key = GlobalKey<NavigatorState>();

/// `/cart/delivery-options`, reconstruit depuis l'enum plutôt qu'écrit en dur :
/// une sous-route ne connaît pas son chemin complet, et le recopier serait la
/// sixième occasion de le laisser diverger (R-03).
final String _deliveryOptionsLocation =
    '${AppRoutes.cart.path}/${AppRoutes.deliveryOptions.path}';

/// Les observateurs de navigation, derrière un provider.
///
/// `AnalyticsService.observer` touche `FirebaseAnalytics.instance` à la
/// première lecture, et `SentryNavigatorObserver` son propre client. Construits
/// en dur dans le routeur, ils rendaient `routerProvider` **inconstructible
/// sans `Firebase.initializeApp()`** : la table de routes ne pouvait donc être
/// éprouvée par aucun test. Un point d'injection les remplace, sans rien
/// changer en production.
@Riverpod(keepAlive: true)
List<NavigatorObserver> routerObservers(Ref ref) => [
  AnalyticsService.observer,
  SentryNavigatorObserver(),
];

/// **Une application, un `GoRouter`.**
///
/// ## Ce qui ne va plus
///
/// Le provider était `@riverpod` (donc `autoDispose`) et faisait
/// `ref.watch(authStateChangeProvider)` + `ref.watch(onboardingStatusProvider)`
/// dans son corps. Trois conséquences, pour une seule cause :
///
/// 1. **Trois à quatre routeurs par session.** Chaque émission du flux Firebase
///    (chargement → `null` → utilisateur à la connexion → `null` à la
///    déconnexion) reconstruisait le `GoRouter`. `MaterialApp.router` recevait
///    un nouveau `routerConfig`, l'arbre `Router` était reconstruit, **la pile
///    de navigation était perdue**.
/// 2. **Une fuite par instance.** `GoRouterRefreshStream` s'abonnait au flux
///    dans son constructeur ; le provider n'appelait `ref.onDispose` ni sur le
///    notifier, ni sur le routeur. Chaque ancienne instance gardait une
///    souscription vivante qui continuait d'appeler `notifyListeners()` sur un
///    routeur mort.
/// 3. **Double emploi.** `ref.watch` (qui reconstruit) et `refreshListenable`
///    (qui rafraîchit sans reconstruire) écoutaient la même source. Le second
///    suffit : c'est précisément le mécanisme prévu pour éviter le premier.
///
/// ## Ce qui est en place
///
/// ```text
/// Firebase Auth  ─┐
///                 ├─→ sessionPhase ─→ ValueNotifier ─→ refreshListenable
/// Onboarding     ─┘        │
///                          └─→ lu par `redirect` via ref.read
/// ```
///
/// `keepAlive` + aucun `ref.watch` dans le corps : **une seule instance**, pour
/// la vie de l'application. Le changement de session ne reconstruit plus rien,
/// il déclenche une réévaluation du `redirect`.
///
/// Le `ValueNotifier` ne notifie que sur **changement de valeur** : trois 401
/// simultanés produisent une seule transition `authenticated →
/// unauthenticated`, donc un seul rafraîchissement.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Le pont entre Riverpod et go_router. Seul objet mutable du routage, et il
  // ne porte qu'une valeur énumérée.
  final rafraichissement = ValueNotifier<SessionPhase>(
    ref.read(sessionPhaseProvider),
  );
  // ⚠️ Ce provider n'avance que s'il est lui-même **activement écouté**.
  //
  // Riverpod 3 met en pause un provider dont plus personne n'écoute la valeur,
  // et la pause se propage à ses dépendances : le flux Firebase se désabonne,
  // la phase reste à `bootstrapping`, et l'application ne quitte jamais
  // l'écran de démarrage. En production l'abonnement existe — `MyApp` fait
  // `ref.watch(routerProvider)` —, mais un `container.read(routerProvider)`
  // seul ne suffit pas. C'est pourquoi `router_lifecycle_test` passe par
  // `container.listen` : lire sans écouter ne reproduit pas l'application.
  ref.listen<SessionPhase>(
    sessionPhaseProvider,
    (_, phase) => rafraichissement.value = phase,
  );
  ref.onDispose(rafraichissement.dispose);

  final router = GoRouter(
    navigatorKey: _key,
    // Personne n'atterrit sur l'accueil avant que la session soit connue.
    initialLocation: AppRoutes.splash.path,
    observers: ref.read(routerObserversProvider),
    refreshListenable: rafraichissement,
    // `ref.read` et non `ref.watch` : le `redirect` s'exécute hors de la
    // construction du provider, et c'est `refreshListenable` qui le fait
    // rejouer. Un `watch` ici reconstruirait le routeur — c'est A-01.
    redirect: (context, state) => resolveRedirect(
      phase: ref.read(sessionPhaseProvider),
      matchedLocation: state.matchedLocation,
      uri: state.uri,
    ),
    routes: _routes,
    errorBuilder: (context, state) => NotFoundScreen(key: state.pageKey),
  );
  ref.onDispose(router.dispose);
  return router;
}

/// Le garde unique — **fonction pure**.
///
/// Trois entrées, une sortie, aucune dépendance : ni `Ref`, ni `BuildContext`,
/// ni horloge. C'est délibéré, et c'est le seul moyen d'éprouver la matrice
/// complète (phase × emplacement × `from`) sans monter un arbre de widgets ni
/// toucher au réseau.
///
/// **Entièrement synchrone et déterministe** : des comparaisons de chaînes sur
/// une valeur énumérée. Aucun `await`, aucun appel réseau, aucune écriture — un
/// `redirect` qui interroge le serveur pour savoir où aller est un `redirect`
/// qui s'exécute plusieurs fois par navigation avec des réponses différentes.
///
/// [matchedLocation] est le chemin **sans** la requête (`/signin`), [uri]
/// l'emplacement complet (`/signin?from=%2Fcommandes%2Fabc`). Les deux sont
/// nécessaires : le premier pour décider, le second pour transporter.
@visibleForTesting
String? resolveRedirect({
  required SessionPhase phase,
  required String matchedLocation,
  required Uri uri,
}) {
  final emplacement = matchedLocation;
  final demandee = uri.toString();

  // ── 1. Bootstrap ───────────────────────────────────────────────────────────
  // Ni connecté ni déconnecté : on ne route rien, et surtout on ne monte pas
  // l'accueil « en attendant » (U-03). La destination demandée est reportée sur
  // l'écran de démarrage — c'est le cas de la notification tapée alors que
  // l'application était tuée : elle demande `/commandes/xyz` avant que Firebase
  // ait répondu.
  if (phase == SessionPhase.bootstrapping) {
    if (emplacement == AppRoutes.splash.path) return null;
    return splashLocationFor(demandee);
  }

  final surSplash = emplacement == AppRoutes.splash.path;
  final surOnboarding = emplacement == AppRoutes.onboarding.path;
  final surAuth =
      emplacement == AppRoutes.signIn.path ||
      emplacement == AppRoutes.signUp.path;

  // La destination à restaurer ne vient QUE du paramètre `from` des trois
  // emplacements de transit. Ailleurs, il n'y a rien à restaurer.
  final destination = (surSplash || surAuth)
      ? sanitizeDestination(uri.queryParameters[kFromQueryParameter])
      : null;

  // ── 2. Onboarding ──────────────────────────────────────────────────────────
  if (phase == SessionPhase.onboardingRequired) {
    return surOnboarding ? null : AppRoutes.onboarding.path;
  }
  if (surOnboarding) {
    // Onboarding terminé pendant qu'on y était : on en sort **par l'accueil**,
    // avec ou sans session.
    //
    // Il renvoyait sans session vers `/signin` — c'était le mur d'inscription,
    // resté debout au seul endroit où il fait le plus de dégâts : la toute
    // première ouverture de l'application, juste après un carrousel de
    // présentation qui vient de promettre un catalogue. Ouvrir le mode
    // visiteur partout ailleurs et le laisser ici aurait fait qu'un nouvel
    // installateur — le seul public qui n'a jamais rien vu de Lilia Food —
    // reste précisément celui à qui on demande un compte avant tout.
    return AppRoutes.home.path;
  }

  // ── 3. Sortie de l'écran de démarrage ──────────────────────────────────────
  if (surSplash) {
    if (phase == SessionPhase.authenticated) {
      return destination ?? AppRoutes.home.path;
    }
    // Pas de session : **l'accueil est public**. On ne passe par la connexion
    // que si la destination demandée l'exige — typiquement une notification
    // tapée sur `/commandes/xyz` alors que la session a expiré. Auparavant, ce
    // chemin envoyait tout le monde sur `/signin` : ouvrir l'application
    // revenait à buter sur un mur d'inscription avant d'avoir vu une seule
    // information.
    if (destination != null &&
        requiresAuthentication(Uri.parse(destination).path)) {
      return signInLocationFor(destination);
    }
    return destination ?? AppRoutes.home.path;
  }

  // ── 4. Sans session ────────────────────────────────────────────────────────
  if (phase == SessionPhase.unauthenticated) {
    if (surAuth) return null; // déjà au bon endroit, `from` intact
    // Découverte : rien à demander. La frontière vit dans une seule table
    // (`protected_locations.dart`), pas dans une condition par écran.
    if (!requiresAuthentication(emplacement)) return null;
    // R-05 : c'est ici que la destination est mémorisée. Sans cela, un client
    // renvoyé au login depuis `/commandes/xyz` atterrissait sur l'accueil après
    // s'être connecté, et devait retrouver sa commande lui-même.
    return signInLocationFor(demandee);
  }

  // ── 5. Avec session ────────────────────────────────────────────────────────
  if (surAuth) {
    return destination ?? AppRoutes.home.path;
  }
  return null;
}

/// Emplacement racine de chaque branche de la coque, **dans l'ordre des
/// onglets**.
///
/// ⚠️ Elle existe parce que `StatefulNavigationShell.goBranch` **ne passe pas
/// par `redirect`** : c'est une bascule interne de pile, pas une navigation.
/// Un invité qui tape « Commandes » atterrissait donc sur l'écran protégé sans
/// que le garde soit consulté — le seul chemin de l'application qui échappait à
/// `resolveRedirect`.
///
/// La coque interroge cette liste et la **même** table
/// (`requiresAuthentication`) que le routeur : une seule règle, deux points
/// d'entrée. `router_guest_test` vérifie que l'ordre correspond bien aux
/// branches déclarées ci-dessous.
const List<String> kShellBranchLocations = <String>[
  '/', // Accueil
  '/cart', // Panier
  '/commandes', // Commandes
  '/profile', // Profil
];

/// La table des routes, extraite du provider : elle ne dépend d'aucun état et
/// n'a donc aucune raison d'être reconstruite avec lui.
final List<RouteBase> _routes = [
  GoRoute(
    path: AppRoutes.splash.path,
    name: AppRoutes.splash.routeName,
    pageBuilder: (context, state) => const MaterialPage(child: SplashScreen()),
  ),
  GoRoute(
    path: AppRoutes.onboarding.path,
    name: AppRoutes.onboarding.routeName,
    pageBuilder: (context, state) =>
        const MaterialPage(child: OnboardingScreen()),
  ),
  GoRoute(
    path: AppRoutes.signIn.path,
    name: AppRoutes.signIn.routeName,
    pageBuilder: (context, state) => const MaterialPage(child: SignInPage()),
  ),
  GoRoute(
    path: AppRoutes.signUp.path,
    name: AppRoutes.signUp.routeName,
    pageBuilder: (context, state) => const MaterialPage(child: SignUpPage()),
  ),
  GoRoute(
    path: AppRoutes.orderSuccess.path,
    name: AppRoutes.orderSuccess.routeName,
    pageBuilder: (context, state) =>
        const MaterialPage(child: OrderSuccessPage()),
  ),

  GoRoute(
    path: AppRoutes.reviews.path,
    name: AppRoutes.reviews.routeName,
    pageBuilder: (context, state) {
      final extra = state.extra;
      if (extra is! Map<String, dynamic> ||
          extra['restaurantId'] is! String ||
          extra['restaurantName'] is! String) {
        return const MaterialPage(child: NotFoundScreen());
      }
      return MaterialPage(
        child: ReviewsScreen(
          restaurantId: extra['restaurantId'] as String,
          restaurantName: extra['restaurantName'] as String,
        ),
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.writeReview.path,
        name: AppRoutes.writeReview.routeName,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic> ||
              extra['restaurantId'] is! String ||
              extra['restaurantName'] is! String) {
            return const MaterialPage(child: NotFoundScreen());
          }
          return MaterialPage(
            child: WriteReviewScreen(
              restaurantId: extra['restaurantId'] as String,
              restaurantName: extra['restaurantName'] as String,
              existingReviewId: extra['existingReviewId'] as String?,
            ),
          );
        },
      ),
    ],
  ),

  // Route principale avec la barre de navigation
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return BottomNavigationPage(navigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.home.path,
            name: AppRoutes.home.routeName,
            pageBuilder: (context, state) =>
                const MaterialPage(child: HomeScreen()),
            routes: [
              // Route restaurant detail - maintenant sous Home pour garder la bottom bar
              GoRoute(
                path: AppRoutes.restaurantDetail.path,
                name: AppRoutes.restaurantDetail.routeName,
                pageBuilder: (context, state) {
                  final restaurantId = state.pathParameters['id'];
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  if (restaurantId == null) {
                    return const MaterialPage(child: NotFoundScreen());
                  }
                  return MaterialPage(
                    child: RestaurantDetailScreen(
                      restaurantId: restaurantId,
                      restaurantName:
                          extra["restaurantName"] as String? ??
                          'Votre Restaurant',
                    ),
                  );
                },
              ),
              GoRoute(
                path: AppRoutes.productDetail.path,
                name: AppRoutes.productDetail.routeName,
                pageBuilder: (context, state) {
                  final Product? product = state.extra as Product?;
                  if (product == null) {
                    return const MaterialPage(child: NotFoundScreen());
                  }
                  return MaterialPage(child: ProductDetailPage(product: product));
                },
              ),
              GoRoute(
                path: AppRoutes.search.path,
                name: AppRoutes.search.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: SearchScreen()),
              ),
              GoRoute(
                path: AppRoutes.menuDetail.path,
                name: AppRoutes.menuDetail.routeName,
                pageBuilder: (context, state) {
                  final MenuDuJour? menu = state.extra as MenuDuJour?;
                  if (menu == null) {
                    return const MaterialPage(child: NotFoundScreen());
                  }
                  return MaterialPage(child: MenuDetailPage(menu: menu));
                },
              ),
              // Historique local des notifications. Était poussé par
              // `Navigator.push` depuis l'accueil : invisible pour
              // `AnalyticsService.observer` et pour le fil d'Ariane Sentry.
              GoRoute(
                path: AppRoutes.notifications.path,
                name: AppRoutes.notifications.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: NotificationsHistoryScreen()),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.cart.path,
            name: AppRoutes.cart.routeName,
            pageBuilder: (context, state) =>
                const MaterialPage(child: CartScreen()),
            routes: [
              GoRoute(
                path: AppRoutes.deliveryOptions.path,
                name: AppRoutes.deliveryOptions.routeName,
                pageBuilder: (context, state) {
                  return const MaterialPage(child: DeliveryOptionsPage());
                },
                routes: [
                  GoRoute(
                    path: AppRoutes.checkout.path,
                    name: AppRoutes.checkout.routeName,
                    // R-04 : le paiement n'a de sens qu'avec un mode de
                    // livraison choisi. La page se rattrapait elle-même par un
                    // `addPostFrameCallback → goNamed(deliveryOptions)`, ce qui
                    // affichait une frame de page de paiement vide avant de
                    // rebondir. Le refus appartient au routeur : la page n'est
                    // jamais construite.
                    redirect: (context, state) => state.extra is DeliveryOptions
                        ? null
                        : _deliveryOptionsLocation,
                    pageBuilder: (context, state) {
                      final deliveryOptions = state.extra as DeliveryOptions?;
                      return MaterialPage(
                        child: CheckoutPage(deliveryOptions: deliveryOptions),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.commandes.path,
            name: AppRoutes.commandes.routeName,
            pageBuilder: (context, state) =>
                const MaterialPage(child: CommandePage()),
            routes: [
              // ⚠️ Déclarée AVANT `:orderId` : go_router évalue les routes
              // dans l'ordre, et `:orderId` capterait sinon
              // `/commandes/paiement/...` en croyant lire un identifiant.
              GoRoute(
                path: AppRoutes.paymentPending.path,
                name: AppRoutes.paymentPending.routeName,
                pageBuilder: (context, state) {
                  final paymentId = state.pathParameters['paymentId']!;
                  final extra = state.extra;
                  // Arrivée par lien profond ou reprise après tuerie du
                  // processus : sans le contexte du paiement, on renvoie sur
                  // la liste des commandes plutôt que d'afficher un écran
                  // d'attente vide.
                  if (extra is! PaymentPendingArgs) {
                    return const MaterialPage(child: CommandePage());
                  }
                  return MaterialPage(
                    child: PaymentPendingPage(
                      paymentId: paymentId,
                      orderId: extra.orderId,
                      amount: extra.amount,
                      method: extra.method,
                    ),
                  );
                },
              ),
              GoRoute(
                path: AppRoutes.orderDetail.path,
                name: AppRoutes.orderDetail.routeName,
                pageBuilder: (context, state) {
                  final orderId = state.pathParameters['orderId']!;
                  return MaterialPage(child: OrderDetailPage(orderId: orderId));
                },
                routes: [
                  // Suivi de livraison en plein écran. Était poussé par
                  // `Navigator.push` : c'est l'écran qu'on regarderait en cas
                  // d'incident, et il n'apparaissait dans aucune mesure.
                  GoRoute(
                    path: AppRoutes.orderTracking.path,
                    name: AppRoutes.orderTracking.routeName,
                    pageBuilder: (context, state) => MaterialPage(
                      child: FullscreenTrackingScreen(
                        orderId: state.pathParameters['orderId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.profile.path,
            name: AppRoutes.profile.routeName,
            pageBuilder: (context, state) =>
                const MaterialPage(child: UserPage()),
            routes: [
              GoRoute(
                path: AppRoutes.favoris.path,
                name: AppRoutes.favoris.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: FavorisPage()),
                routes: [
                  GoRoute(
                    path: AppRoutes.favoriteDetail.path,
                    name: AppRoutes.favoriteDetail.routeName,
                    pageBuilder: (context, state) {
                      final Product? product = state.extra as Product?;
                      if (product == null) {
                        return const MaterialPage(child: NotFoundScreen());
                      }
                      return MaterialPage(
                        child: FavorisDetailPage(product: product),
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.address.path,
                name: AppRoutes.address.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: AddressPage()),
              ),
              GoRoute(
                path: AppRoutes.changePassword.path,
                name: AppRoutes.changePassword.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: ChangePasswordPage()),
              ),
              GoRoute(
                path: AppRoutes.draftOrders.path,
                name: AppRoutes.draftOrders.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: DraftOrdersScreen()),
              ),
              // Édition du profil et « À propos » : tous deux poussés par
              // `Navigator.push` depuis l'écran de profil, donc hors mesure.
              GoRoute(
                path: AppRoutes.editProfile.path,
                name: AppRoutes.editProfile.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: EditProfilePage()),
              ),
              GoRoute(
                path: AppRoutes.about.path,
                name: AppRoutes.about.routeName,
                pageBuilder: (context, state) =>
                    const MaterialPage(child: AboutPage()),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
