import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../models/restaurant.dart';

part 'restaurant_controller.g.dart';

/// Provider pour récupérer la liste de tous les restaurants
@riverpod
Future<List<RestaurantSummary>> restaurantsList(Ref ref) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getAllRestaurants();
}

/// Provider pour récupérer un restaurant spécifique avec ses produits
/// keepAlive: true pour garder les données en cache quand on quitte la page
@Riverpod(keepAlive: true)
Future<Restaurant> restaurantController(
    Ref ref, String restaurantId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getRestaurant(restaurantId);
}