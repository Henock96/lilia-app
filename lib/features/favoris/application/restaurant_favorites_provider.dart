import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/restaurant.dart';

part 'restaurant_favorites_provider.g.dart';

const _kRestaurantFavoritesKey = 'restaurant_favorites';

@riverpod
class RestaurantFavorites extends _$RestaurantFavorites {
  late SharedPreferences _prefs;

  @override
  Future<List<RestaurantSummary>> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _getFavorites();
  }

  List<RestaurantSummary> _getFavorites() {
    final favoritesJson = _prefs.getStringList(_kRestaurantFavoritesKey) ?? [];
    return favoritesJson
        .map((jsonString) => RestaurantSummary.fromJson(jsonDecode(jsonString)))
        .toList();
  }

  Future<void> _setFavorites(List<RestaurantSummary> restaurants) async {
    final favoritesJson = restaurants
        .map((restaurant) => jsonEncode(restaurant.toJson()))
        .toList();
    await _prefs.setStringList(_kRestaurantFavoritesKey, favoritesJson);
    state = AsyncData(restaurants);
  }

  Future<void> toggleFavorite(RestaurantSummary restaurant) async {
    final currentFavorites = await future;
    final isFav = currentFavorites.any((r) => r.id == restaurant.id);

    if (isFav) {
      await remove(restaurant);
    } else {
      await add(restaurant);
    }
  }

  Future<void> add(RestaurantSummary restaurant) async {
    final currentFavorites = await future;
    if (!currentFavorites.any((r) => r.id == restaurant.id)) {
      final updatedFavorites = [...currentFavorites, restaurant];
      await _setFavorites(updatedFavorites);
    }
  }

  Future<void> remove(RestaurantSummary restaurant) async {
    final currentFavorites = await future;
    final updatedFavorites = currentFavorites
        .where((r) => r.id != restaurant.id)
        .toList();
    await _setFavorites(updatedFavorites);
  }

  Future<bool> isFavorite(String restaurantId) async {
    final currentFavorites = await future;
    return currentFavorites.any((r) => r.id == restaurantId);
  }
}

/// Provider pour vérifier si un restaurant est en favori (sync)
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
