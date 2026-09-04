import 'dart:convert';
import 'package:lilia_app/core/network/api_client.dart';
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

  /// Récupérer un vendeur par son ID avec ses produits (LIL-117).
  /// Bascule de /restaurants/:id → /vendors/:id pour récupérer aussi
  /// vendorProfile (story, certifications, specialties, productionNote)
  /// utilisé par l'écran de détail vendeur (HOME_COOK / BAKERY surtout).
  /// Backend filtre déjà isActive + adminApproved.
  Future<Restaurant> getRestaurant(String id) async {
    final res = await _api.getJson('/vendors/$id');
    return Restaurant.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }
}

@Riverpod(keepAlive: true)
RestaurantRepository restaurantRepository(Ref ref) {
  return RestaurantRepository(ref.watch(apiClientProvider));
}
