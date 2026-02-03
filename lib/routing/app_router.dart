import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/presentation/cart_screen.dart';
import 'package:lilia_app/features/commandes/presentation/checkout_page.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/commandes/presentation/commande_page.dart';
import 'package:lilia_app/features/commandes/presentation/order_success_page.dart';
import 'package:lilia_app/features/favoris/presentation/favoris_detail_page.dart';
import 'package:lilia_app/features/favoris/presentation/favoris_page.dart';
import 'package:lilia_app/features/home/presentation/bottom_navigation_bar.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lilia_app/features/user/user_page.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/routing/go_router_refresh_stream.dart';
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
import '../features/reviews/presentation/screens/reviews_screen.dart';
import '../features/reviews/presentation/screens/write_review_screen.dart';
import '../models/menu.dart';
import '../models/produit.dart';
import 'app_route_enum.dart';

part 'app_router.g.dart';

final _key = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(Ref ref) {
  // Écoute l'état d'authentification réel via le StreamProvider.
  // C'est la source de vérité pour savoir si l'utilisateur est connecté.
  final authState = ref.watch(authStateChangeProvider);

  // Écoute l'état de l'onboarding
  final onboardingState = ref.watch(onboardingStatusProvider);

  return GoRouter(
    navigatorKey: _key,
    initialLocation: AppRoutes.home.path,
    // Le refreshListenable doit écouter le même flux pour déclencher la redirection.
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authRepositoryProvider).authStateChanges(),
    ),
    redirect: (context, state) {
      // Vérifier si l'onboarding est complété
      final bool onboardingCompleted = onboardingState.when(
        data: (completed) => completed,
        loading: () => true, // Pendant le chargement, on assume que c'est fait
        error: (_, __) => true, // En cas d'erreur, on skip l'onboarding
      );

      final bool isOnboardingPage =
          state.matchedLocation == AppRoutes.onboarding.path;

      // Si l'onboarding n'est pas complété et on n'est pas sur la page d'onboarding
      if (!onboardingCompleted && !isOnboardingPage) {
        return AppRoutes.onboarding.path;
      }

      // Si l'onboarding est complété et on est sur la page d'onboarding
      if (onboardingCompleted && isOnboardingPage) {
        return AppRoutes.signIn.path;
      }

      // Gère les différents états de l'AsyncValue pour l'authentification
      final bool isLoggedIn = authState.when(
        data: (user) =>
            user != null, // L'utilisateur est connecté s'il y a des données
        loading: () =>
            false, // Pendant le chargement, on considère l'utilisateur comme non connecté
        error: (_, __) =>
            false, // En cas d'erreur, on considère l'utilisateur comme non connecté
      );

      final bool isLoggingIn =
          state.matchedLocation == AppRoutes.signIn.path ||
          state.matchedLocation == AppRoutes.signUp.path;

      // Redirige vers la page de connexion si l'utilisateur n'est pas connecté
      // et n'est pas déjà sur une page de connexion/inscription.
      if (!isLoggedIn && !isLoggingIn && onboardingCompleted) {
        return AppRoutes.signIn.path;
      }

      // Redirige vers la page d'accueil si l'utilisateur est connecté
      // et se trouve sur une page de connexion/inscription.
      if (isLoggedIn && isLoggingIn) {
        return AppRoutes.home.path;
      }

      // Aucune redirection nécessaire dans les autres cas.
      return null;
    },
    routes: [
      // Route Onboarding
      GoRoute(
        path: AppRoutes.onboarding.path,
        name: AppRoutes.onboarding.routeName,
        pageBuilder: (context, state) =>
            const MaterialPage(child: OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.signIn.path,
        name: AppRoutes.signIn.routeName,
        pageBuilder: (context, state) =>
            const MaterialPage(child: SignInPage()),
      ),
      GoRoute(
        path: AppRoutes.signUp.path,
        name: AppRoutes.signUp.routeName,
        pageBuilder: (context, state) =>
            const MaterialPage(child: SignUpPage()),
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
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
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
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null) {
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
                    path: 'restaurant/:id',
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
                          restaurantName: extra["restaurantName"] is String
                              ? extra["restaurantName"]
                              : 'Votre Restaurant',
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'product-detail',
                    name: AppRoutes.productDetail.routeName,
                    pageBuilder: (context, state) {
                      final Product? product = state.extra as Product?;
                      if (product == null) {
                        return const MaterialPage(child: NotFoundScreen());
                      }
                      return MaterialPage(
                        child: ProductDetailPage(product: product),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'menu-detail',
                    name: AppRoutes.menuDetail.routeName,
                    pageBuilder: (context, state) {
                      final MenuDuJour? menu = state.extra as MenuDuJour?;
                      if (menu == null) {
                        return const MaterialPage(child: NotFoundScreen());
                      }
                      return MaterialPage(child: MenuDetailPage(menu: menu));
                    },
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
                        pageBuilder: (context, state) {
                          final deliveryOptions =
                              state.extra as DeliveryOptions?;
                          return MaterialPage(
                            child: CheckoutPage(
                              deliveryOptions: deliveryOptions,
                            ),
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
                  GoRoute(
                    path:
                        ':orderId', // Paramètre de chemin pour l'ID de la commande
                    name:
                        AppRoutes.orderDetail.routeName, // Nouveau nom de route
                    pageBuilder: (context, state) {
                      final orderId = state.pathParameters['orderId']!;
                      return MaterialPage(
                        child: OrderDetailPage(orderId: orderId),
                      );
                    },
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
                          return MaterialPage(
                            child: FavorisDetailPage(product: product!),
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
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => NotFoundScreen(key: state.pageKey),
  );
}
