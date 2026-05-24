import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/cart/application/cart_controller.dart';
import '../../../models/produit.dart';
import '../../../models/restaurant.dart';
import '../../../routing/app_route_enum.dart';
import '../../../services/analytics_service.dart';
import '../data/remote/home_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            style: TextStyle(fontSize: 15, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Rechercher un plat ou restaurant...',
              hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              icon: Icon(Icons.close, color: cs.onSurfaceVariant),
            ),
        ],
      ),
      body: _query.isEmpty ? _buildEmptyState(cs) : _buildSearchResults(cs),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Recherchez un plat ou un restaurant',
            style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ColorScheme cs) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return resultsAsync.when(
      data: (results) {
        AnalyticsService.logSearchFromHome(
          query: _query,
          resultCount: results.restaurants.length + results.products.length,
        );
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Aucun resultat pour "$_query"',
                  style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (results.restaurants.isNotEmpty) ...[
              Text(
                'Restaurants',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...results.restaurants.map(
                (r) => _SearchRestaurantTile(restaurant: r),
              ),
              const SizedBox(height: 20),
            ],
            if (results.products.isNotEmpty) ...[
              Text(
                'Plats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...results.products.map((p) => _SearchProductTile(product: p)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Erreur: $err',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SearchRestaurantTile extends StatelessWidget {
  final RestaurantSummary restaurant;

  const _SearchRestaurantTile({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: ListTile(
        onTap: () {
          context.goNamed(
            AppRoutes.restaurantDetail.routeName,
            pathParameters: {'id': restaurant.id},
            extra: {'restaurantName': restaurant.name},
          );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: restaurant.imageUrl != null
              ? Image.network(
                  restaurant.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholderBox(
                    cs,
                    const Icon(Icons.restaurant, size: 24),
                  ),
                )
              : _placeholderBox(cs, const Icon(Icons.restaurant, size: 24)),
        ),
        title: Text(
          restaurant.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (restaurant.specialties.isNotEmpty)
              Text(
                restaurant.specialtiesFormatted,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: restaurant.isOpen ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  restaurant.isOpen ? 'Ouvert' : 'Ferme',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 2),
                Text(
                  restaurant.deliveryTimeFormatted,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _placeholderBox(ColorScheme cs, Widget icon) {
    return Container(
      width: 50,
      height: 50,
      color: cs.surfaceContainerHighest,
      child: IconTheme(
        data: IconThemeData(color: cs.onSurfaceVariant, size: 24),
        child: icon,
      ),
    );
  }
}

class _SearchProductTile extends ConsumerWidget {
  final Product product;

  const _SearchProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: ListTile(
        onTap: () {
          context.pushNamed(AppRoutes.productDetail.routeName, extra: product);
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.imageUrl != null
              ? Image.network(
                  product.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholderBox(cs),
                )
              : _placeholderBox(cs),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.restaurantName != null)
              Text(
                product.restaurantName!,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            Text(
              '${product.displayPrice.toStringAsFixed(0)} FCFA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ],
        ),
        trailing: product.isAvailable
            ? GestureDetector(
                onTap: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connectez-vous pour ajouter au panier'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (product.variants.length > 1) {
                    _showVariantBottomSheet(context, ref);
                  } else if (product.variants.isNotEmpty) {
                    _addToCart(context, ref, product.variants.first);
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Epuise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _placeholderBox(ColorScheme cs) {
    return Container(
      width: 50,
      height: 50,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.fastfood, size: 24, color: cs.onSurfaceVariant),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref, ProductVariant variant) {
    AnalyticsService.logAddToCartFromHome(
      productId: product.id,
      productName: product.name,
      source: 'search',
      price: variant.prix,
    );
    ref
        .read(cartControllerProvider.notifier)
        .addItem(variantId: variant.id)
        .then((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${product.name} ajouté au panier'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
  }

  void _showVariantBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetCs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choisir une option',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...product.variants.map((variant) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _addToCart(context, ref, variant);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: sheetCs.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          variant.label,
                          style: TextStyle(
                            fontSize: 14,
                            color: sheetCs.onSurface,
                          ),
                        ),
                        Text(
                          '${variant.prix.toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: sheetCs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
