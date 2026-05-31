import 'package:lilia_app/features/home/data/remote/restaurant_repo.dart';
import 'package:lilia_app/models/vendor_type.dart';
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
Future<Restaurant> restaurantController(Ref ref, String restaurantId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getRestaurant(restaurantId);
}

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].
@riverpod
class MarketplaceFilter extends _$MarketplaceFilter {
  @override
  VendorType? build() => null;

  void set(VendorType? type) => state = type;

  void reset() => state = null;
}

/// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
/// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
/// Riverpod rebuilde et refetch automatiquement.
@riverpod
Future<List<RestaurantSummary>> vendorsList(Ref ref) async {
  final filter = ref.watch(marketplaceFilterProvider);
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getVendors(vendorType: filter);
}
