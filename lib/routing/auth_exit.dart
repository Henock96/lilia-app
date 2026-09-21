/// **La sortie de l'écran de connexion — sans elle, le mode visiteur est un
/// couloir à sens unique.**
///
/// ## Le problème
///
/// `/signin` et `/signup` ne sont jamais *poussés* : on y arrive par le
/// `redirect` du routeur, qui **remplace** l'emplacement courant
/// (`resolveRedirect` → `signInLocationFor`). La pile de navigation est donc
/// vide à l'arrivée : `context.canPop()` vaut `false`, un `AppBar` n'affiche
/// aucune flèche, et le retour matériel Android ferme l'application.
///
/// Un visiteur qui composait son panier et bute sur « Options de livraison »
/// n'a alors **plus aucun moyen de revenir à son panier** : il crée un compte
/// ou il quitte. C'est le mur d'inscription que le mode visiteur venait
/// d'abattre, réinstallé un écran plus loin.
///
/// ## La règle
///
/// Le retour ne « dépile » pas — il n'y a rien à dépiler. Il **remonte le
/// chemin demandé jusqu'au premier emplacement public**, et retombe sur
/// l'accueil quand il n'y en a aucun :
///
/// ```text
/// /cart/delivery-options  →  /cart          le panier, articles intacts
/// /commandes/abc          →  /              rien de public au-dessus
/// /profile/address        →  /
/// /reviews/write/xyz      →  /reviews       lire les avis reste public
/// (aucun `from`)          →  /
/// ```
///
/// C'est la même table que le garde (`requiresAuthentication`) qui tranche :
/// une route reclassée demain déplace le retour avec elle, sans qu'on y pense.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_route_enum.dart';
import 'pending_destination.dart';
import 'protected_locations.dart';

/// Où mène le retour depuis un écran d'authentification atteint avec [from].
///
/// **Fonction pure** sur la destination seule, pour la même raison que
/// `resolveRedirect` et `sanitizeDestination` : la matrice complète doit être
/// éprouvable sans monter un widget ni toucher au routeur.
///
/// [from] est la valeur brute du paramètre de requête — elle passe donc par
/// `sanitizeDestination`, qui refuse les redirections ouvertes, les chemins
/// relatifs et les boucles. Une valeur refusée n'est pas une erreur : elle
/// signifie seulement qu'il n'y a rien à restaurer, et l'accueil est la bonne
/// réponse.
String publicExitFor(String? from) {
  final destination = sanitizeDestination(from);
  if (destination == null) return AppRoutes.home.path;

  // On remonte sur le CHEMIN seul. La requête (`?tab=avis`) décrit un état de
  // l'écran demandé ; elle n'a aucun sens sur son parent.
  var chemin = Uri.parse(destination).path;

  while (chemin.isNotEmpty && chemin != AppRoutes.home.path) {
    if (!requiresAuthentication(chemin)) return chemin;
    final coupure = chemin.lastIndexOf('/');
    // `coupure == 0` ⇒ le parent est la racine : on sort par l'accueil plutôt
    // que par la chaîne vide, que go_router ne saurait pas router.
    chemin = coupure <= 0 ? AppRoutes.home.path : chemin.substring(0, coupure);
  }

  return AppRoutes.home.path;
}

/// Quitte l'écran d'authentification pour le premier emplacement public.
///
/// Pendant de `goToAuthRoute`, et pour le même motif : la destination demandée
/// vit dans l'URL de l'écran courant, pas dans un état partagé. C'est le seul
/// endroit où la lire pour décider du retour.
///
/// ## `pop` d'abord, `go` ensuite — et pourquoi l'ordre compte
///
/// `go` ne revient pas en arrière : il **construit une nouvelle pile**. L'écran
/// d'arrivée est donc reconstruit, son état local perdu, et les providers
/// `autoDispose` qu'il observe redemandés au serveur. Mesuré : un aller-retour
/// par `go` fait passer l'écran de destination d'une création à deux.
///
/// Quand une pile existe, `pop` la préserve intégralement — rien n'est
/// reconstruit, rien n'est rechargé. On ne retombe sur `go` que lorsqu'il n'y a
/// littéralement rien à dépiler, ce qui reste le cas nominal ici : on arrive
/// sur cet écran par un `redirect`, et un `redirect` remplace.
void goBackFromAuthRoute(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final from = GoRouterState.of(
    context,
  ).uri.queryParameters[kFromQueryParameter];
  context.go(publicExitFor(from));
}
