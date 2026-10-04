import '../../../models/produit.dart';
import '../../../models/restaurant.dart';
import '../../../models/search_result.dart';

/// Résultats de recherche rangés pour l'affichage.
///
/// **Pas de filtre « Disponible maintenant / Tout voir ».** Un interrupteur
/// cacherait des résultats, et le soir, quand presque tout est fermé à
/// Brazzaville, il afficherait un écran vide au client qui cherche « poulet ».
/// Les deux groupes restent visibles, les commandables d'abord : on voit tout
/// de suite ce qu'on peut commander, et ce qu'on ne peut pas commander reste
/// consultable avec sa raison.
///
/// Le classement ne recrée aucune règle métier : il relaie
/// [Product.unavailability], qui lit les verdicts du serveur (boutique
/// ouverte, retrait, stock par format, fenêtre de vente). L'ordre **dans**
/// chaque groupe est celui du serveur (boutiques ouvertes d'abord, puis
/// l'ordre public du catalogue).
class SearchSections {
  const SearchSections({
    required this.vendors,
    required this.orderableProducts,
    required this.unavailableProducts,
  });

  factory SearchSections.from(SearchResult result) {
    final orderable = <Product>[];
    final unavailable = <Product>[];
    for (final p in result.products) {
      (p.isOrderable ? orderable : unavailable).add(p);
    }
    return SearchSections(
      vendors: result.restaurants,
      orderableProducts: orderable,
      unavailableProducts: unavailable,
    );
  }

  final List<RestaurantSummary> vendors;
  final List<Product> orderableProducts;
  final List<Product> unavailableProducts;

  int get total =>
      vendors.length + orderableProducts.length + unavailableProducts.length;

  bool get isEmpty => total == 0;
}

/// Suggestions de recherche tirées de produits **réellement commandables**
/// (réponse de `GET /products/available-now`) : leurs catégories, sans
/// doublon, dans l'ordre du serveur. La recherche serveur couvre le nom de
/// catégorie, donc chaque suggestion rend au moins le produit qui l'a fait
/// naître. Aucune liste écrite à la main : « jus » proposé en dur ne rendait
/// rien en production.
List<String> searchSuggestionsFrom(List<Product> products, {int max = 8}) {
  final seen = <String>{};
  final out = <String>[];
  for (final p in products) {
    final name = p.category?.name.trim();
    if (name == null || name.isEmpty) continue;
    if (seen.add(name.toLowerCase())) out.add(name);
    if (out.length == max) break;
  }
  return out;
}
