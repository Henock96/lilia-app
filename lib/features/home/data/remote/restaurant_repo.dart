import 'dart:convert';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/utils/json_isolate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/restaurant.dart';

part 'restaurant_repo.g.dart';

/// Décodage + mapping d'une liste `{ data: [...] }` de vendeurs.
/// Top-level → exécutable sur isolate (cf. [parseJson]).
List<RestaurantSummary> _parseRestaurantSummaries(String body) {
  final List<dynamic> data = json.decode(body)['data'] as List<dynamic>;
  return data
      .map((e) => RestaurantSummary.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Idem pour une page de produits (`GET /products`). Top-level : contrainte
/// isolate.
List<Product> _parseProducts(String body) {
  final List<dynamic> data = json.decode(body)['data'] as List<dynamic>;
  return data
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
}

class RestaurantRepository {
  final ApiClient _api;

  RestaurantRepository(this._api);

  /// Récupérer la liste de tous les restaurants (legacy /restaurants —
  /// backend filtre déjà sur adminApproved=true depuis Sprint B).
  Future<List<RestaurantSummary>> getAllRestaurants() async {
    final body = await _api.getText('/restaurants');
    return parseJson(body, _parseRestaurantSummaries);
  }

  /// Marketplace multi-vendeurs (LIL-117) — GET /vendors avec filtre
  /// optionnel par VendorType. Backend filtre déjà sur isActive +
  /// adminApproved, on ne reçoit donc que les vendeurs visibles publiquement.
  /// Réponse paginée `{ data, meta }` — on garde uniquement `data`.
  Future<List<RestaurantSummary>> getVendors({VendorType? vendorType}) async {
    final body = await _api.getText(
      '/vendors',
      query: {
        if (vendorType != null) 'vendorType': vendorType.name,
        'limit': '50',
      },
    );
    return parseJson(body, _parseRestaurantSummaries);
  }

  /// **La carte d'un vendeur** — `GET /vendors/:id`, source canonique.
  ///
  /// Depuis la phase 2, le site consomme la **même** route : les deux
  /// construisaient auparavant leur catalogue séparément (`/restaurants/:id` du
  /// côté web) et avaient divergé sur six points — produits épuisés exclus ici,
  /// aucun tri, aucune borne, note moyenne absente.
  ///
  /// La réponse porte `totalProducts` et `hasMoreProducts` : quand la carte
  /// dépasse la borne du serveur, on complète en paginant `GET /products`, qui
  /// applique exactement le même `where` et le même `orderBy` (garanti par
  /// `vendor-menu-parity.spec.ts`). Sans cette continuité, la page 2 ferait
  /// réapparaître des produits de la page 1 et en sauterait d'autres.
  ///
  /// ⚠️ Ces deux champs étaient servis depuis août et **lus par aucun client** :
  /// la carte était donc tronquée en silence, et comme l'écran masque les
  /// sections vides, des sections entières disparaissaient.
  Future<Restaurant> getRestaurant(String id) async {
    final res = await _api.getJson('/vendors/$id');
    final data = (res.data as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
    final vendor = Restaurant.fromJson(data);

    final total = (data['totalProducts'] as num?)?.toInt();
    final hasMore = data['hasMoreProducts'] as bool? ?? false;
    if (!hasMore || total == null || vendor.products.length >= total) {
      return vendor;
    }

    final rest = await _fetchRemainingProducts(
      id,
      alreadyLoaded: vendor.products.length,
      total: total,
    );
    return vendor.withProducts([...vendor.products, ...rest]);
  }

  /// Pages suivantes du catalogue d'un vendeur.
  ///
  /// Plafond dur : une boucle « tant qu'il reste des pages » pilotée par une
  /// réponse serveur est une boucle pilotée de l'extérieur — un `totalPages`
  /// aberrant suffirait à figer l'écran.
  ///
  /// Un échec en cours de route n'est pas fatal : on rend ce qu'on a. Une carte
  /// partielle vaut mieux qu'un écran d'erreur sur un vendeur qui a du stock.
  Future<List<Product>> _fetchRemainingProducts(
    String restaurantId, {
    required int alreadyLoaded,
    required int total,
  }) async {
    const pageSize = 100; // MAX_PAGE_SIZE côté serveur
    const maxPages = 20;

    final collected = <Product>[];
    var page = (alreadyLoaded ~/ pageSize) + 1;

    for (var i = 0; i < maxPages; i++) {
      try {
        final body = await _api.getText(
          '/products',
          query: {
            'restaurantId': restaurantId,
            'page': '${page + i}',
            'limit': '$pageSize',
          },
        );
        final batch = await parseJson(body, _parseProducts);
        if (batch.isEmpty) break;
        collected.addAll(batch);
        if (alreadyLoaded + collected.length >= total) break;
      } catch (_) {
        break;
      }
    }
    return collected;
  }
}

@Riverpod(keepAlive: true)
RestaurantRepository restaurantRepository(Ref ref) {
  return RestaurantRepository(ref.watch(apiClientProvider));
}
