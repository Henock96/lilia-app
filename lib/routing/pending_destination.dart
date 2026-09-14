import 'app_route_enum.dart';

/// Nom du paramètre de requête qui transporte la destination demandée.
///
/// `/signin?from=%2Fcommandes%2Fabc` — la convention go_router habituelle.
const String kFromQueryParameter = 'from';

/// Les emplacements qui ne peuvent **jamais** être une destination à restaurer.
///
/// Y renvoyer après une connexion réussie boucle : le `redirect` verrait un
/// client connecté sur un écran de connexion et le renverrait aussitôt, avec la
/// même destination, indéfiniment.
final Set<String> _emplacementsNonRestaurables = <String>{
  AppRoutes.splash.path,
  AppRoutes.signIn.path,
  AppRoutes.signUp.path,
  AppRoutes.onboarding.path,
};

/// Longueur maximale acceptée pour une destination.
///
/// Une URL de 4 Ko n'arrive pas d'un écran de l'application : elle arrive d'un
/// lien fabriqué. On la refuse au lieu de la router.
const int _longueurMax = 512;

/// Nettoie la destination demandée, ou rend `null` si elle n'est pas sûre.
///
/// **Fonction pure**, et c'est délibéré : la mémorisation de la destination est
/// le seul endroit du routage où une valeur d'origine externe (paramètre de
/// requête, lien profond, charge utile d'une notification) décide où va le
/// client. Elle doit être testable sans monter quoi que ce soit.
///
/// Ce qui est refusé, et pourquoi :
///
/// | Entrée | Raison du refus |
/// |---|---|
/// | `null`, `''` | rien à restaurer |
/// | `https://exemple.com/x` | redirection ouverte — un lien externe déguisé |
/// | `//exemple.com/x` | même chose, forme « relative au protocole » |
/// | `commandes/abc` | chemin relatif : go_router le résoudrait par rapport à l'emplacement courant, donc de façon imprévisible |
/// | `/signin`, `/signup`, `/onboarding`, `/splash` | boucle de redirection |
/// | plus de 512 caractères | n'a pas pu être produit par l'application |
/// | URI non analysable | idem |
///
/// Ce qui est **conservé** : la requête et le fragment (`/restaurant/1?tab=avis`),
/// parce qu'un écran peut en dépendre. Seul le `from` imbriqué est retiré — un
/// `?from=` qui en contient un autre est un aller-retour dont rien n'a besoin.
String? sanitizeDestination(String? brute) {
  if (brute == null) return null;

  final valeur = brute.trim();
  if (valeur.isEmpty || valeur.length > _longueurMax) return null;

  // Doit être un chemin absolu **interne**. Le second test attrape `//hôte/x`,
  // que `Uri.parse` lit comme une autorité et non comme un chemin.
  if (!valeur.startsWith('/') || valeur.startsWith('//')) return null;

  final uri = Uri.tryParse(valeur);
  if (uri == null) return null;
  if (uri.hasScheme || uri.hasAuthority) return null;
  if (!uri.path.startsWith('/')) return null;

  if (_emplacementsNonRestaurables.contains(uri.path)) return null;

  // Un `from` imbriqué ne sert à rien et rallonge l'URL à chaque tour.
  final parametres = Map<String, String>.from(uri.queryParameters)
    ..remove(kFromQueryParameter);

  return Uri(
    path: uri.path,
    queryParameters: parametres.isEmpty ? null : parametres,
    fragment: (uri.fragment.isEmpty) ? null : uri.fragment,
  ).toString();
}

/// Construit `/signin?from=…`, ou `/signin` tout court si la destination n'est
/// pas restaurable.
String signInLocationFor(String? destination) =>
    _avecFrom(AppRoutes.signIn.path, destination);

/// Construit `/splash?from=…`.
///
/// Le paramètre traverse l'écran de démarrage : une notification tapée alors
/// que l'application était tuée demande `/commandes/xyz` **avant** que Firebase
/// ait résolu la session. Sans ce report, la commande est perdue — le client
/// arrive sur l'accueil et doit la retrouver lui-même.
String splashLocationFor(String? destination) =>
    _avecFrom(AppRoutes.splash.path, destination);

String _avecFrom(String base, String? destination) {
  final propre = sanitizeDestination(destination);
  if (propre == null) return base;
  return Uri(
    path: base,
    queryParameters: {kFromQueryParameter: propre},
  ).toString();
}
