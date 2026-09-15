import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_route_enum.dart';
import 'pending_destination.dart';

/// Passe de `/signin` à `/signup` (ou l'inverse) **en gardant la destination
/// demandée**.
///
/// Sans cela, un client renvoyé sur `/signin?from=/commandes/xyz` qui choisit
/// « S'inscrire » perd son `from` en chemin : il crée son compte et atterrit
/// sur l'accueil, la commande qu'il venait consulter oubliée. Le lien entre les
/// deux écrans d'authentification est le seul endroit où la destination peut
/// s'évaporer sans que le routeur s'en aperçoive — elle vit dans l'URL, et
/// cette navigation-là en fabrique une nouvelle.
void goToAuthRoute(BuildContext context, AppRoutes route) {
  assert(
    route == AppRoutes.signIn || route == AppRoutes.signUp,
    'Réservé aux deux écrans d\'authentification.',
  );
  final from = sanitizeDestination(
    GoRouterState.of(context).uri.queryParameters[kFromQueryParameter],
  );
  context.goNamed(
    route.routeName,
    queryParameters: {kFromQueryParameter: ?from},
  );
}
