import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../models/produit.dart';
import '../../../../models/restaurant.dart';
import '../../../../models/search_result.dart';
import 'home_repo.dart';

part 'home_controller.g.dart';

/// Provider pour les plats populaires
@riverpod
Future<List<Product>> popularProducts(Ref ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getPopularProducts(limit: 10);
}

/// Provider pour les restaurants populaires
@riverpod
Future<List<RestaurantSummary>> popularRestaurants(Ref ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getPopularRestaurants(limit: 6);
}

/// Provider pour les recommandations (basées sur l'historique utilisateur)
@riverpod
Future<List<Product>> recommendations(Ref ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getRecommendations(limit: 10);
}

/// Provider pour la liste des catégories
@riverpod
Future<List<Category>> categoriesList(Ref ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getCategories();
}

/// Provider pour les résultats de recherche
@riverpod
Future<SearchResult> searchResults(Ref ref, String query) async {
  if (query.trim().isEmpty) {
    return SearchResult(restaurants: [], products: []);
  }
  final repo = ref.watch(homeRepositoryProvider);
  return repo.search(query);
}
