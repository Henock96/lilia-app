import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/star_rating.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/produit.dart';
import '../../../models/restaurant.dart';
import '../../../routing/app_route_enum.dart';
import '../data/remote/restaurant_controller.dart';
import 'widgets/menus_section.dart';

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantAsyncValue = ref.watch(
      restaurantControllerProvider(widget.restaurantId),
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(widget.restaurantName),
        actions: [
          // Bouton partager
          IconButton(
            onPressed: () => _shareRestaurant(),
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
          ),
          // Bouton avis
          IconButton(
            onPressed: () {
              context.pushNamed(
                AppRoutes.reviews.routeName,
                extra: {
                  'restaurantId': widget.restaurantId,
                  'restaurantName': widget.restaurantId,
                },
              );
            },
            icon: const Icon(Icons.star_border, color: Colors.amber),
            tooltip: 'Voir les avis',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantControllerProvider(widget.restaurantId));
        },
        child: restaurantAsyncValue.when(
          data: (restaurant) => _buildContent(restaurant),
          loading: () => const BuildLoadingState(),
          error: (err, stack) => BuildErrorState(
            err,
            onRetry: () => ref.invalidate(
              restaurantControllerProvider(widget.restaurantId),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Restaurant restaurant) {
    // Obtenir les catégories uniques
    final categories = _getUniqueCategories(restaurant.products);

    // Filtrer les produits
    final filteredProducts = _filterProducts(restaurant.products);

    // Grouper par catégorie
    final productsByCategory = _groupByCategory(filteredProducts);

    return CustomScrollView(
      slivers: [
        // Info du restaurant
        SliverToBoxAdapter(
          child: _RestaurantInfoCard(
            restaurant: restaurant,
            onCall: () => _callRestaurant(restaurant.phoneNumber),
          ),
        ),

        // Barre de recherche
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),

        // Onglets de catégories
        if (categories.isNotEmpty)
          SliverToBoxAdapter(
            child: _CategoryTabs(
              categories: categories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() {
                  _selectedCategory = category;
                });
              },
            ),
          ),

        // Section des Menus du Jour
        SliverToBoxAdapter(
          child: MenusSection(restaurantId: widget.restaurantId),
        ),

        // Titre produits
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Nos Produits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // Liste des produits groupés par catégorie
        if (filteredProducts.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Aucun produit trouvé',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...productsByCategory.entries.map((entry) {
            return SliverToBoxAdapter(
              child: _CategorySection(
                categoryName: entry.key,
                products: entry.value,
              ),
            );
          }),

        // Espace en bas
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  List<String> _getUniqueCategories(List<Product> products) {
    final categories = <String>{};
    for (var product in products) {
      if (product.category?.name != null && product.category!.name.isNotEmpty) {
        categories.add(product.category!.name);
      }
    }
    return categories.toList()..sort();
  }

  List<Product> _filterProducts(List<Product> products) {
    return products.where((product) {
      // Filtre par recherche
      if (_searchQuery.isNotEmpty) {
        final matchesSearch =
            product.name.toLowerCase().contains(_searchQuery) ||
            product.description.toLowerCase().contains(_searchQuery);
        if (!matchesSearch) return false;
      }

      // Filtre par catégorie
      if (_selectedCategory != null) {
        if (product.category?.name != _selectedCategory) return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<Product>> _groupByCategory(List<Product> products) {
    final Map<String, List<Product>> grouped = {};
    final List<Product> uncategorized = [];

    for (var product in products) {
      final categoryName = product.category?.name;
      if (categoryName != null && categoryName.isNotEmpty) {
        grouped.putIfAbsent(categoryName, () => []).add(product);
      } else {
        uncategorized.add(product);
      }
    }

    if (uncategorized.isNotEmpty) {
      grouped['Autres'] = uncategorized;
    }

    return grouped;
  }

  void _shareRestaurant() {
    Share.share(
      'Découvrez nos menus sur Lilia Food ! Commandez vos plats préférés maintenant.',
      subject: 'Restaurant ${widget.restaurantName}',
    );
  }

  Future<void> _callRestaurant(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone non disponible')),
      );
      return;
    }

    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'application téléphone'),
          ),
        );
      }
    }
  }
}

// Carte d'info du restaurant
class _RestaurantInfoCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onCall;

  const _RestaurantInfoCard({required this.restaurant, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Adresse
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adresse',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      restaurant.address,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Statut ouvert/fermé
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: restaurant.isOpen
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: restaurant.isOpen ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  restaurant.isOpen ? Icons.check_circle : Icons.cancel,
                  color: restaurant.isOpen ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  restaurant.isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                    color: restaurant.isOpen ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Spécialités
          if (restaurant.specialties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: restaurant.specialties.map((specialty) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    specialty.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const Divider(height: 24),

          // Informations de livraison (dynamiques)
          Row(
            children: [
              _InfoItem(
                icon: Icons.delivery_dining,
                label: 'Livraison',
                value: restaurant.deliveryTimeFormatted,
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              _InfoItem(
                icon: Icons.shopping_bag,
                label: 'Minimum',
                value: restaurant.minimumOrderAmount > 0
                    ? '${restaurant.minimumOrderAmount.toStringAsFixed(0)} FCFA'
                    : 'Aucun',
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _InfoItem(
                icon: Icons.local_shipping,
                label: 'Frais',
                value: '${restaurant.fixedDeliveryFee.toStringAsFixed(0)} FCFA',
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bouton appeler
          if (restaurant.phoneNumber != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.phone, size: 18),
                label: Text('Appeler ${restaurant.phoneNumber}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Onglets de catégories
class _CategoryTabs extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final Function(String?) onCategorySelected;

  const _CategoryTabs({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Bouton "Tous"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('Tous'),
              selected: selectedCategory == null,
              onSelected: (_) => onCategorySelected(null),
              selectedColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            ),
          ),
          // Boutons de catégories
          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: (_) => onCategorySelected(
                  selectedCategory == category ? null : category,
                ),
                selectedColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.2),
                checkmarkColor: Theme.of(context).primaryColor,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Widget pour une section de catégorie
class _CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Product> products;

  const _CategorySection({required this.categoryName, required this.products});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${products.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...products.map((product) {
            return GestureDetector(
              onTap: () {
                context.goNamed(
                  AppRoutes.productDetail.routeName,
                  extra: product,
                );
              },
              child: _ProductCard(product: product),
            );
          }),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  double getDisplayPrice() {
    if (product.variants.isNotEmpty) {
      return product.variants.first.prix;
    }
    return product.prixOriginal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image avec badge promo si applicable
            Stack(
              children: [
                Container(
                  width: 85,
                  height: 85,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[200],
                    image: product.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(product.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product.imageUrl == null
                      ? const Center(
                          child: Icon(
                            Icons.fastfood,
                            size: 40,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                ),
                if (product.variants.isNotEmpty && product.variants.length > 1)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.variants.length} tailles',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
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
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${getDisplayPrice().toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      // Bouton ajouter au panier
                      InkWell(
                        onTap: () => _addToCart(context, ref),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref) {
    if (product.variants.isNotEmpty) {
      final variantId = product.variants.first.id;
      ref.read(cartControllerProvider.notifier).addItem(variantId: variantId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('${product.name} ajouté au panier')),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce produit n\'a pas de variante sélectionnable.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
