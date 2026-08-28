import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../models/produit.dart';
import '../../../../models/restaurant.dart';
import '../../../../models/search_result.dart';
import '../../../../utils/api_response.dart';
import '../../../../utils/json_isolate.dart';

part 'home_repo.g.dart';

// Parsers top-level (décodage + mapping) déportables sur isolate via
// [parseJson] quand le payload dépasse le seuil. Cf. utils/json_isolate.dart.
List<Product> _parseProducts(String body) {
  final List<dynamic> data = json.decode(body)['data'] as List<dynamic>;
  return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
}

List<RestaurantSummary> _parsePopularRestaurants(String body) {
  final List<dynamic> data = json.decode(body)['data'] as List<dynamic>;
  return data
      .map((j) => RestaurantSummary.fromJson(j as Map<String, dynamic>))
      .toList();
}

SearchResult _parseSearchResult(String body) =>
    SearchResult.fromJson(ApiResponse.mapOf(json.decode(body)));

class HomeRepository {
  final ApiClient _api;

  HomeRepository(this._api);

  /// GET /products/popular?limit=10
  Future<List<Product>> getPopularProducts({int limit = 10}) async {
    final body = await _api.getText(
      '/products/popular',
      query: {'limit': '$limit'},
    );
    return parseJson(body, _parseProducts);
  }

  /// GET /restaurants/popular?limit=6
  Future<List<RestaurantSummary>> getPopularRestaurants({int limit = 6}) async {
    final body = await _api.getText(
      '/restaurants/popular',
      query: {'limit': '$limit'},
    );
    return parseJson(body, _parsePopularRestaurants);
  }

  /// GET /products/search?q=...
  Future<SearchResult> search(String query) async {
    // Tolère objet plat OU `{ data: {...} }` (api-contract-v2).
    final body = await _api.getText('/products/search', query: {'q': query});
    return parseJson(body, _parseSearchResult);
  }

  /// GET /products/recommendations (authentifié)
  Future<List<Product>> getRecommendations({int limit = 10}) async {
    try {
      final body = await _api.getText(
        '/products/recommendations',
        query: {'limit': '$limit'},
      );
      return parseJson(body, _parseProducts);
    } on ApiException catch (e) {
      // Recommandations = feature non bloquante : on dégrade en liste vide,
      // mais on trace l'erreur en debug au lieu de l'avaler totalement (C12).
      if (kDebugMode) {
        debugPrint('getRecommendations failed: ${e.message}');
      }
      return [];
    }
  }

  /// GET /categories
  Future<List<Category>> getCategories() async {
    final res = await _api.getJson('/categories');
    // /categories double-enveloppé (`{ data: { data: [...], count } }`).
    final data = ApiResponse.listOf(ApiResponse.mapOf(res.data));
    return data
        .map((j) => Category.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
HomeRepository homeRepository(Ref ref) {
  return HomeRepository(ref.watch(apiClientProvider));
}
