import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/presentation/cart_screen.dart';
import 'package:lilia_app/features/commandes/presentation/checkout_page.dart';
import 'package:lilia_app/features/commandes/presentation/commande_page.dart';
import 'package:lilia_app/features/commandes/presentation/order_success_page.dart';
import 'package:lilia_app/features/favoris/presentation/favoris_page.dart';
import 'package:lilia_app/features/home/presentation/bottom_navigation_bar.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/user/user_page.dart';
import 'package:lilia_app/routing/go_router_refresh_stream.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/signin_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/commandes/presentation/commande_detail_page.dart';
import '../features/home/presentation/not_found_page.dart';
import '../features/home/presentation/product_detail_page.dart';
import '../models/produit.dart';
import 'app_route_enum.dart';

part 'app_router.g.dart';

final _key = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authRepositoryProvider);
  return GoRouter(
      navigatorKey: _key,
      initialLocation: AppRoutes.home.path,
      refreshListenable: GoRouterRefreshStream(authState.authStateChanges()),
      redirect: (context, state) {
        final bool isLoggedIn = authState.currentUser != null;
        final bool isLoggingIn = state.matchedLocation == AppRoutes.signIn.path ||
            state.matchedLocation == AppRoutes.signUp.path;

        // should redirect the user to the sign in page if they are not logged in
        if (!isLoggedIn && !isLoggingIn) {
          return AppRoutes.signIn.path;
        }

        // should redirect the user after they have logged in
        if (isLoggedIn && isLoggingIn) {
          return AppRoutes.home.path;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.signIn.path,
          name: AppRoutes.signIn.routeName,
          pageBuilder: (context, state) => const MaterialPage(
            child: SignInPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.signUp.path,
          name: AppRoutes.signUp.routeName,
          pageBuilder: (context, state) => const MaterialPage(
            child: SignUpPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.cart.path,
          name: AppRoutes.cart.routeName,
          pageBuilder: (context, state) => const MaterialPage(
            child: CartScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.checkout.path,
          name: AppRoutes.checkout.routeName,
          pageBuilder: (context, state) => const MaterialPage(
            child: CheckoutPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.orderSuccess.path,
          name: AppRoutes.orderSuccess.routeName,
          pageBuilder: (context, state) => const MaterialPage(
            child: OrderSuccessPage(),
          ),
        ),
        // * your other routes *
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
                  pageBuilder: (context, state) => const MaterialPage(
                    child: HomeScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path:
                          'product-detail', // Ou 'detail/:productId' si vous voulez passer l'ID dans l'URL
                      name: AppRoutes.productDetail
                          .routeName, // Ajoutez un nom de route dans votre enum
                      pageBuilder: (context, state) {
                        // Récupérer l'objet Product passé via 'extra'
                        final Product? product = state.extra as Product?;
                        if (product == null) {
                          // Gérer le cas où le produit n'est pas passé (erreur, navigation directe sans extra)
                          return const MaterialPage(
                              child:
                                  NotFoundScreen()); // Ou une page d'erreur spécifique
                        }
                        return MaterialPage(
                          child: ProductDetailPage(product: product),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.commandes.path,
                name: AppRoutes.commandes.routeName,
                pageBuilder: (context, state) => const MaterialPage(
                  child: CommandePage(),
                ),
                routes: [
                  GoRoute(
                    path:
                        ':orderId', // Paramètre de chemin pour l'ID de la commande
                    name: AppRoutes.orderDetail.routeName, // Nouveau nom de route
                    pageBuilder: (context, state) {
                      final orderId = state.pathParameters['orderId']!;
                      return MaterialPage(
                        child: OrderDetailPage(orderId: orderId),
                      );
                    },
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.favoris.path,
                name: AppRoutes.favoris.routeName,
                pageBuilder: (context, state) => const MaterialPage(
                  child: FavorisPage(),
                ),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.profile.path,
                name: AppRoutes.profile.routeName,
                pageBuilder: (context, state) => const MaterialPage(
                  child: UserPage(),
                ),
              ),
            ])
          ],
        ),
      ],
      errorBuilder: (context, state) => NotFoundScreen(
            key: state.pageKey,
          ));
}
