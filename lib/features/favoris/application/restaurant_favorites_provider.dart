import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/restaurant.dart';

part 'restaurant_favorites_provider.g.dart';

@Riverpod(keepAlive: true)
class RestaurantFavorites extends _$RestaurantFavorites {
  @override
  Future<List<RestaurantSummary>> build() async {
    return _fetchFromBackend();
  }

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<List<RestaurantSummary>> _fetchFromBackend() async {
    final token = await _getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/favorites'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((e) => RestaurantSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> toggleFavorite(RestaurantSummary restaurant) async {
    final current = await future;
    final isFav = current.any((r) => r.id == restaurant.id);
    if (isFav) {
      await remove(restaurant);
    } else {
      await add(restaurant);
    }
  }

  Future<void> add(RestaurantSummary restaurant) async {
    final token = await _getToken();
    if (token == null) return;

    // Optimistic update
    final current = await future;
    state = AsyncData([...current, restaurant]);

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/favorites/${restaurant.id}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      // Rollback
      state = AsyncData(current);
    }
  }

  Future<void> remove(RestaurantSummary restaurant) async {
    final token = await _getToken();
    if (token == null) return;

    // Optimistic update
    final current = await future;
    state = AsyncData(current.where((r) => r.id != restaurant.id).toList());

    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/favorites/${restaurant.id}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
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
