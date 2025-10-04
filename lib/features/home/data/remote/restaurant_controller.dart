import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../models/restaurant.dart';

part 'restaurant_controller.g.dart';

@riverpod
Future<Restaurant> restaurantController(
    Ref ref, String restaurantId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getRestaurant(restaurantId);
}