import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../models/produit.dart';
import '../../../../models/restaurant.dart';
import '../../../../models/search_result.dart';
import 'package:lilia_app/utils/provider_cache.dart';

import 'home_repo.dart';
import 'restaurant_controller.dart';

part 'home_controller.g.dart';

// `popularProducts` a été SUPPRIMÉ (UI Refresh, 30/09/2026) : il classait
// tout l'historique puis retirait les plats non servables, et montrait des
// plats de boutiques fermées. L'accueil et le panier vide lisent
// `availableNow`. `GET /products/popular` reste servi aux versions installées.

/// Durée de vie de « Disponible maintenant ».
///
/// Courte : la liste dit ce qui est commandable **maintenant**, et une
/// boutique ferme à l'heure dite. Ce n'est pas une garantie — le checkout
/// recalcule l'ouverture et le stock et reste l'autorité.
const Duration kAvailableNowTtl = Duration(seconds: 60);

/// « Disponible maintenant » pour le filtre courant (`marketplaceFilter`).
///
/// Changer de puce refait l'appel ; la section rafraîchit en plus au retour
/// au premier plan et chaque minute tant qu'elle est affichée
/// (`AvailableNowSection`).
@riverpod
Future<AvailableNow> availableNow(Ref ref) async {
  cachePendant(ref, kAvailableNowTtl);
  ref.watch(staleForegroundStampProvider);

  final filter = ref.watch(marketplaceFilterProvider);
  return ref
      .watch(homeRepositoryProvider)
      .getAvailableNow(vendorType: filter, limit: 10);
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

/// Provider pour les résultats de recherche
@riverpod
Future<SearchResult> searchResults(Ref ref, String query) async {
  if (query.trim().isEmpty) {
    return SearchResult(restaurants: [], products: []);
  }
  final repo = ref.watch(homeRepositoryProvider);
  return repo.search(query);
}

/// **Un produit, par son identifiant.**
///
/// Existe pour que `/product/:productId` soit une adresse complète : la fiche
/// se rendait uniquement depuis un `Product` passé en `extra` de navigation,
/// et `extra` ne survit pas à une mort de processus. Le client qui revenait
/// dans l'application après un appel téléphonique tombait sur « page
/// introuvable ».
///
/// Mis en cache comme les listes du catalogue : revenir sur une fiche déjà
/// vue ne coûte rien pendant cinq minutes, et au-delà les prix et la
/// disponibilité sont redemandés.
@riverpod
Future<Product> productById(Ref ref, String productId) async {
  cachePendant(ref, kCatalogCacheTtl);
  ref.watch(staleForegroundStampProvider);
  return ref.watch(homeRepositoryProvider).getProduct(productId);
}
