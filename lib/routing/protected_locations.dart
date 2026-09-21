/// **La frontière entre découvrir et transiger — écrite une fois.**
///
/// ## Ce qu'elle remplace
///
/// `resolveRedirect` renvoyait vers `/signin` **tout** emplacement demandé sans
/// session. Personne ne pouvait donc ouvrir l'application sans commencer par
/// créer un compte : ni voir un vendeur, ni regarder un prix, ni décider si le
/// service l'intéresse. Le mur d'inscription arrivait avant la première
/// information.
///
/// ## La règle
///
/// ```text
/// DÉCOUVRIR    = public       accueil, vendeurs, produits, recherche, panier
/// TRANSIGER    = authentifié  commandes, profil, adresses, paiement
/// ```
///
/// Les deux listes sont **complémentaires et exhaustives** : tout emplacement
/// de `AppRoutes` tombe dans l'une ou dans l'autre, et
/// `protected_locations_test` le vérifie route par route. C'est ce qui
/// distingue cette table d'une liste d'exceptions — une route ajoutée demain
/// sans y être classée fait échouer le test, au lieu de devenir publique par
/// omission.
///
/// ## Ce qu'elle ne fait pas
///
/// Elle ne protège **rien**. Le contrôle d'accès réel vit sur le serveur, où
/// `/orders`, `/adresses`, `/users/me` et `/cart` exigent un jeton Firebase.
/// Cette table décide seulement **quand demander à se connecter** — assez tôt
/// pour que le client ne bute pas sur un écran vide, assez tard pour qu'il ait
/// pu voir ce qu'il achète.
library;

import 'app_route_enum.dart';

/// Chemins complets (racine comprise) qui exigent une session.
///
/// Un préfixe couvre son sous-arbre : `/profile` protège `/profile/address`,
/// `/profile/favoris/details`, et tout ce qui viendra s'y greffer. C'est
/// délibéré — une sous-route oubliée hérite alors de la protection de son
/// parent plutôt que de tomber dans le public.
final List<String> _prefixesProteges = <String>[
  // Historique et suivi de commandes : la liste et le détail sont ceux du
  // client connecté, et le serveur ne rend rien d'autre.
  AppRoutes.commandes.path,

  // Profil, adresses, favoris, fidélité, parrainage, brouillons.
  AppRoutes.profile.path,

  // Confirmation de commande : il n'y a rien à confirmer sans commande.
  AppRoutes.orderSuccess.path,

  // ⚠️ LA frontière du parcours d'achat.
  //
  // Le panier (`/cart`) est public : c'est encore de la découverte, le client
  // compose et regarde le total. `/cart/delivery-options` ne l'est plus — il
  // demande de choisir une adresse enregistrée, donc un compte, et il mène au
  // paiement. C'est ici, et nulle part ailleurs, que la connexion est réclamée.
  '${AppRoutes.cart.path}/${AppRoutes.deliveryOptions.path}',

  // Historique local des notifications : il ne parle que de commandes.
  '/${AppRoutes.notifications.path}',

  // Laisser un avis suppose une commande livrée ; **lire** les avis, non.
  '${AppRoutes.reviews.path}/${AppRoutes.writeReview.path}',
];

/// Cet emplacement exige-t-il une session ouverte ?
///
/// **Fonction pure** sur le chemin seul (sans requête) — la même forme que
/// `resolveRedirect`, pour la même raison : la matrice complète doit être
/// éprouvable sans monter un widget ni toucher au réseau.
///
/// La comparaison est un préfixe **de segment** : `/cart` ne doit pas protéger
/// `/cartographie`, et `/commandes` ne protège `/commandes/abc` que parce que
/// la frontière tombe sur un `/`.
///
/// ⚠️ Un segment `:param` du motif correspond à **n'importe quel** segment non
/// vide de l'emplacement.
///
/// Sans cela, rendre une route adressable la faisait sortir de la table en
/// silence. C'est arrivé : `/reviews/write` est devenu
/// `/reviews/:restaurantId/write` pour survivre à une mort de processus, et
/// une comparaison littérale ne reconnaissait plus `/reviews/abc/write`.
/// Rédiger un avis redevenait public — un durcissement de routage annulant
/// une règle d'accès, sans qu'une ligne de la table ait changé.
bool requiresAuthentication(String location) {
  final segmentsChemin = _segments(_sansBarreFinale(location));
  for (final prefixe in _prefixesProteges) {
    if (_prefixeCorrespond(_segments(prefixe), segmentsChemin)) return true;
  }
  return false;
}

List<String> _segments(String chemin) =>
    chemin.split('/').where((s) => s.isNotEmpty).toList();

/// [motif] couvre-t-il [chemin] — lui-même ou l'un de ses descendants ?
bool _prefixeCorrespond(List<String> motif, List<String> chemin) {
  if (motif.length > chemin.length) return false;
  for (var i = 0; i < motif.length; i++) {
    if (motif[i].startsWith(':')) continue; // un paramètre accepte tout
    if (motif[i] != chemin[i]) return false;
  }
  return true;
}

/// `/commandes/` et `/commandes` désignent le même écran. Sans cette
/// normalisation, la première forme échapperait à la comparaison exacte et ne
/// serait rattrapée que par le préfixe — donc pas du tout pour une route
/// protégée sans enfant.
String _sansBarreFinale(String chemin) =>
    (chemin.length > 1 && chemin.endsWith('/'))
    ? chemin.substring(0, chemin.length - 1)
    : chemin;

/// Exposée pour le test d'exhaustivité, qui doit pouvoir énumérer la table
/// plutôt que de la recopier.
List<String> get protectedLocationPrefixes =>
    List<String>.unmodifiable(_prefixesProteges);
