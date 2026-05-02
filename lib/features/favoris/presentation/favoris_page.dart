import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
import 'package:lilia_app/features/favoris/application/restaurant_favorites_provider.dart';

import '../../../models/produit.dart';
import '../../../models/restaurant.dart';

class FavorisPage extends ConsumerWidget {
  const FavorisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes Favoris'),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.primaryColor,
            tabs: const [
              Tab(icon: Icon(Icons.fastfood, size: 20), text: 'Plats'),
              Tab(icon: Icon(Icons.restaurant, size: 20), text: 'Restaurants'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProductFavoritesTab(),
            _RestaurantFavoritesTab(),
          ],
        ),
      ),
    );
  }
}

// ============ ONGLET PLATS FAVORIS ============

class _ProductFavoritesTab extends ConsumerWidget {
  const _ProductFavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return favorites.when(
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/fav.jpg", width: 150, height: 150),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Text(
                    'Aucun plat en favoris pour le moment !',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return ProductCardFavoris(product: products[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur: $error')),
    );
  }
}

class ProductCardFavoris extends ConsumerWidget {
  final Product product;

  const ProductCardFavoris({super.key, required this.product});

  double getDisplayPrice() {
    if (product.variants.isNotEmpty) return product.variants.first.prix;
    return product.prixOriginal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref
        .watch(favoritesProvider)
        .maybeWhen(
          data: (favorites) => favorites.any((p) => p.id == product.id),
          orElse: () => false,
        );
    return GestureDetector(
      onTap: () {
        context.pushNamed(AppRoutes.favoriteDetail.routeName, extra: product);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Hero(
                tag: 'favorite_${product.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.fastfood, size: 36, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[200],
                          ),
                          child: const Center(
                            child: Icon(Icons.fastfood, size: 36, color: Colors.grey),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (product.restaurantName != null)
                      Text(
                        product.restaurantName!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (product.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${getDisplayPrice().toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                ),
                onPressed: () {
                  final notifier = ref.read(favoritesProvider.notifier);
                  if (isFavorite) {
                    notifier.remove(product);
                  } else {
                    notifier.add(product);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ ONGLET RESTAURANTS FAVORIS ============

class _RestaurantFavoritesTab extends ConsumerWidget {
  const _RestaurantFavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(restaurantFavoritesProvider);

    return favorites.when(
      data: (restaurants) {
        if (restaurants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Aucun restaurant en favoris',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explorez et ajoutez vos restaurants preferes',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: restaurants.length,
          itemBuilder: (context, index) {
            return _RestaurantFavoriteCard(restaurant: restaurants[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur: $error')),
    );
  }
}

class _RestaurantFavoriteCard extends ConsumerWidget {
  final RestaurantSummary restaurant;

  const _RestaurantFavoriteCard({required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        context.goNamed(
          AppRoutes.restaurantDetail.routeName,
          pathParameters: {'id': restaurant.id},
          extra: {'restaurantName': restaurant.name},
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Opacity(
          opacity: restaurant.isOpen ? 1.0 : 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: restaurant.imageUrl != null
                        ? Image.network(
                            restaurant.imageUrl!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 120,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.restaurant, size: 40, color: Colors.grey),
                              ),
                            ),
                          )
                        : Container(
                            height: 120,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.restaurant, size: 40, color: Colors.grey),
                            ),
                          ),
                  ),
                  // Badge ouvert/ferme
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: restaurant.isOpen ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        restaurant.isOpen ? 'Ouvert' : 'Ferme',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Bouton retirer des favoris
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(restaurantFavoritesProvider.notifier)
                            .remove(restaurant);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${restaurant.name} retire des favoris'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite, color: Colors.red, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              // Infos
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (restaurant.averageRating != null &&
                            restaurant.totalReviews != null &&
                            restaurant.totalReviews! > 0)
                          Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.amber[700]),
                              const SizedBox(width: 2),
                              Text(
                                '${restaurant.averageRating!.toStringAsFixed(1)} (${restaurant.totalReviews})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (restaurant.specialties.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: restaurant.specialties.take(3).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.deliveryTimeFormatted,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.delivery_dining_outlined, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.fixedDeliveryFee.toStringAsFixed(0)} FCFA',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
