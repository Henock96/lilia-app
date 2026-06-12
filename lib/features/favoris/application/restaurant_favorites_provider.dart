import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/restaurant.dart';

part 'restaurant_favorites_provider.g.dart';

@Riverpod(keepAlive: true)
class RestaurantFavorites extends _$RestaurantFavorites {
  @override
  Future<List<RestaurantSummary>> build() async {
    return _fetchFromBackend();
  }

  // IDs en cours de bascule : empêche les appels concurrents (double-tap)
  // sur un même restaurant d'envoyer add + remove qui se croisent (C9).
  final Set<String> _toggling = {};

  ApiClient get _api => ref.read(apiClientProvider);

  Future<List<RestaurantSummary>> _fetchFromBackend() async {
    try {
      final res = await _api.getJson('/favorites');
      // Tolère payload brut `[...]` OU wrappé `{ data: [...] }` (api-contract-v2).
      return ApiResponse.listOf(res.data)
          .map((e) => RestaurantSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      // Non connecté / erreur : liste vide (favoris = feature non bloquante).
      return [];
    }
  }

  Future<void> toggleFavorite(RestaurantSummary restaurant) async {
    // Ignore si une bascule est déjà en vol pour ce restaurant.
    if (!_toggling.add(restaurant.id)) return;
    try {
      final current = await future;
      final isFav = current.any((r) => r.id == restaurant.id);
      if (isFav) {
        await remove(restaurant);
      } else {
        await add(restaurant);
      }
    } finally {
      _toggling.remove(restaurant.id);
    }
  }

  Future<void> add(RestaurantSummary restaurant) async {
    // Optimistic update
    final current = await future;
    state = AsyncData([...current, restaurant]);

    try {
      await _api.postJson('/favorites/${restaurant.id}');
    } on ApiException {
      // Rollback
      state = AsyncData(current);
    }
  }

  Future<void> remove(RestaurantSummary restaurant) async {
    // Optimistic update
    final current = await future;
    state = AsyncData(current.where((r) => r.id != restaurant.id).toList());

    try {
      await _api.deleteJson('/favorites/${restaurant.id}');
    } on ApiException {
      // Rollback
      state = AsyncData(current);
    }
  }
}

/// Provider synchrone pour vérifier si un restaurant est favori
@riverpod
bool isRestaurantFavorite(Ref ref, String restaurantId) {
  final favoritesAsync = ref.watch(restaurantFavoritesProvider);
  return favoritesAsync.when(
    data: (favorites) => favorites.any((r) => r.id == restaurantId),
    loading: () => false,
    error: (_, _) => false,
  );
}

extension RestaurantSummaryJson on RestaurantSummary {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': name,
      'adresse': address,
      'phone': phoneNumber,
      'imageUrl': imageUrl,
      'description': description,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
    };
  }
}
