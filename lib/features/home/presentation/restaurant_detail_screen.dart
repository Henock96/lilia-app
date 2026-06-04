import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/produit.dart';
import '../../../models/restaurant.dart';
import '../../../models/vendor_type.dart';
import '../../../routing/app_route_enum.dart';
import '../../cart/presentation/cart_mode_conflict_dialog.dart';
import '../data/remote/restaurant_controller.dart';
import 'widgets/menus_section.dart';
import 'widgets/vendor_type_badge.dart';
import 'package:lilia_app/utils/currency.dart';

/// Écran de détail vendeur (LIL-117 — refonte UI).
///
/// Layout :
///   1. Hero image plein écran avec back/share/reviews/favoris floating
///   2. Carte d'identité : nom, type vendeur, note, statut ouvert/fermé
///   3. Story + spécialités/certifications/note de production (si VendorProfile)
///   4. Quick info livraison (temps, frais, minimum)
///   5. Horaires (collapsible)
///   6. Bouton "Appeler"
///   7. Menus du jour
///   8. Search + tabs catégories
///   9. Produits groupés par catégorie
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
  void initState() {
    super.initState();
    AnalyticsService.logRestaurantViewed(
      restaurantId: widget.restaurantId,
      restaurantName: widget.restaurantName,
    );
  }

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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantControllerProvider(widget.restaurantId));
        },
        child: restaurantAsyncValue.when(
          data: _buildContent,
          loading: () => const BuildLoadingState(),
          error: (err, _) => BuildErrorState(
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
    final categories = _getUniqueCategories(restaurant.products);
    final filteredProducts = _filterProducts(restaurant.products);
    final productsByCategory = _groupByCategory(filteredProducts);

    return CustomScrollView(
      slivers: [
        // 1. Hero
        _VendorHeroAppBar(
          restaurant: restaurant,
          onShare: _shareRestaurant,
          onReviews: () => context.pushNamed(
            AppRoutes.reviews.routeName,
            extra: {
              'restaurantId': widget.restaurantId,
              'restaurantName': restaurant.name,
            },
          ),
        ),

        // 2. Carte d'identité (titre, type, rating, statut)
        SliverToBoxAdapter(
          child: _VendorIdentityCard(restaurant: restaurant),
        ),

        // 3. Story + profil enrichi (HOME_COOK/BAKERY surtout)
        if (restaurant.vendorProfile != null &&
            !restaurant.vendorProfile!.isEmpty)
          SliverToBoxAdapter(
            child: _VendorProfileSection(profile: restaurant.vendorProfile!),
          ),

        // 4. Spécialités (chips Specialty[])
        if (restaurant.specialties.isNotEmpty)
          SliverToBoxAdapter(
            child: _SpecialtyChipsSection(specialties: restaurant.specialties),
          ),

        // 5. Quick info livraison
        SliverToBoxAdapter(
          child: _DeliveryInfoCard(restaurant: restaurant),
        ),

        // 6. Horaires
        if (restaurant.operatingHours.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _OperatingHoursSection(
                operatingHours: restaurant.operatingHours,
              ),
            ),
          ),

        // 7. Appeler
        if (restaurant.phoneNumber != null && restaurant.phoneNumber!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _callRestaurant(restaurant.phoneNumber),
                  icon: const Icon(Icons.phone, size: 18),
                  label: Text('Appeler ${restaurant.phoneNumber}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 8. Menus du jour
        SliverToBoxAdapter(
          child: MenusSection(restaurantId: widget.restaurantId),
        ),

        // 9. Section produits — header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu, size: 22),
                const SizedBox(width: 8),
                Text(
                  _productsHeading(restaurant.vendorType),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 10. Search produit
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
        ),

        // 11. Onglets catégories
        if (categories.isNotEmpty)
          SliverToBoxAdapter(
            child: _CategoryTabs(
              categories: categories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (c) => setState(() => _selectedCategory = c),
            ),
          ),

        // 12. Liste des produits
        if (filteredProducts.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48),
                    SizedBox(height: 16),
                    Text('Aucun produit trouvé',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          )
        else
          ...productsByCategory.entries.map(
            (entry) => SliverToBoxAdapter(
              child: _CategorySection(
                categoryName: entry.key,
                products: entry.value,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  String _productsHeading(VendorType type) {
    switch (type) {
      case VendorType.BAKERY:
        return 'Nos viennoiseries';
      case VendorType.HOME_COOK:
        return 'Nos préparations';
      case VendorType.BEVERAGE_SHOP:
        return 'Nos boissons';
      case VendorType.GROCERY:
        return 'Nos produits';
      case VendorType.RESTAURANT:
        return 'Nos produits';
    }
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
      if (_searchQuery.isNotEmpty) {
        final matches = product.name.toLowerCase().contains(_searchQuery) ||
            product.description.toLowerCase().contains(_searchQuery);
        if (!matches) return false;
      }
      if (_selectedCategory != null &&
          product.category?.name != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<Product>> _groupByCategory(List<Product> products) {
    final grouped = <String, List<Product>>{};
    final uncategorized = <Product>[];
    for (var product in products) {
      final name = product.category?.name;
      if (name != null && name.isNotEmpty) {
        grouped.putIfAbsent(name, () => []).add(product);
      } else {
        uncategorized.add(product);
      }
    }
    if (uncategorized.isNotEmpty) grouped['Autres'] = uncategorized;
    return grouped;
  }

  void _shareRestaurant() {
    SharePlus.instance.share(
      ShareParams(
        text: 'Découvrez nos menus sur Lilia Food ! Commandez maintenant.',
        subject: 'Vendeur ${widget.restaurantName}',
      ),
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir l\'application téléphone'),
        ),
      );
    }
  }
}

// ─── Hero AppBar ────────────────────────────────────────────────────────────

class _VendorHeroAppBar extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onShare;
  final VoidCallback onReviews;

  const _VendorHeroAppBar({
    required this.restaurant,
    required this.onShare,
    required this.onReviews,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      stretch: true,
      backgroundColor: scheme.surface,
      elevation: 0,
      leading: _circleButton(
        context,
        icon: Icons.arrow_back,
        onTap: () => Navigator.of(context).pop(),
      ),
      actions: [
        _circleButton(context, icon: Icons.share_outlined, onTap: onShare),
        _circleButton(
          context,
          icon: Icons.star_outline,
          iconColor: Colors.amber,
          onTap: onReviews,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (restaurant.imageUrl != null)
              Hero(
                tag: 'resto-img-${restaurant.id}',
                child: Image.network(
                  restaurant.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(scheme),
                ),
              )
            else
              _placeholder(scheme),
            // Gradient en bas pour la lisibilité du nom + transition douce
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Badge type vendeur posé en haut à gauche sous l'AppBar
            Positioned(
              top: 100,
              left: 16,
              child: VendorTypeBadge(vendorType: restaurant.vendorType),
            ),
            // Nom + adresse en bas
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  Widget _placeholder(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.restaurant, size: 96, color: scheme.outline),
        ),
      );

  Widget _circleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? scheme.onSurface),
        onPressed: onTap,
      ),
    );
  }
}

// ─── Carte identité (titre, type, rating, statut) ───────────────────────────

class _VendorIdentityCard extends StatelessWidget {
  final Restaurant restaurant;

  const _VendorIdentityCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Statut ouvert/fermé
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                      restaurant.isOpen
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: restaurant.isOpen ? Colors.green : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      restaurant.isOpen ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        color: restaurant.isOpen ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Rating + reviews
              if (restaurant.averageRating != null &&
                  restaurant.averageRating! > 0) ...[
                const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  restaurant.averageRating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (restaurant.totalReviews != null)
                  Text(
                    ' (${restaurant.totalReviews})',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Profil enrichi (story + certifications + production note) ──────────────

class _VendorProfileSection extends StatelessWidget {
  final VendorProfile profile;

  const _VendorProfileSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.story != null && profile.story!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'À propos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                profile.story!,
                style: const TextStyle(fontSize: 13.5, height: 1.45),
              ),
            ],
            if (profile.certifications.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ChipsRow(
                icon: Icons.verified_outlined,
                label: 'Certifications',
                items: profile.certifications,
                accent: Colors.teal,
              ),
            ],
            if (profile.specialties.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ChipsRow(
                icon: Icons.star_outline,
                label: 'Spécialités',
                items: profile.specialties,
                accent: Colors.deepOrange,
              ),
            ],
            if (profile.productionNote != null &&
                profile.productionNote!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      profile.productionNote!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> items;
  final Color accent;

  const _ChipsRow({
    required this.icon,
    required this.label,
    required this.items,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: accent,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─── Spécialités cuisine (Specialty[] séparé du VendorProfile) ─────────────

class _SpecialtyChipsSection extends StatelessWidget {
  final List<Specialty> specialties;

  const _SpecialtyChipsSection({required this.specialties});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: specialties
            .map(
              (s) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  s.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Quick info livraison ──────────────────────────────────────────────────

class _DeliveryInfoCard extends StatelessWidget {
  final Restaurant restaurant;

  const _DeliveryInfoCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _InfoTile(
            icon: Icons.delivery_dining,
            label: 'Livraison',
            value: restaurant.deliveryTimeFormatted,
            color: Colors.blue,
          ),
          const SizedBox(width: 10),
          _InfoTile(
            icon: Icons.local_shipping_outlined,
            label: 'Frais',
            value: restaurant.fixedDeliveryFee == 0
                ? 'Gratuit'
                : formatPrice(restaurant.fixedDeliveryFee),
            color: Colors.green,
          ),
          const SizedBox(width: 10),
          _InfoTile(
            icon: Icons.shopping_bag_outlined,
            label: 'Minimum',
            value: restaurant.minimumOrderAmount > 0
                ? formatPrice(restaurant.minimumOrderAmount)
                : 'Aucun',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Onglets catégories ────────────────────────────────────────────────────

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('Tous'),
              selected: selectedCategory == null,
              onSelected: (_) => onCategorySelected(null),
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: (_) => onCategorySelected(
                  selectedCategory == category ? null : category,
                ),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
                checkmarkColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section catégorie ─────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Product> products;

  const _CategorySection({
    required this.categoryName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${products.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...products.map(
            (product) => GestureDetector(
              onTap: () => context.pushNamed(
                AppRoutes.productDetail.routeName,
                extra: product,
              ),
              child: _ProductCard(product: product),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte produit ─────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  double getDisplayPrice() {
    if (product.variants.isNotEmpty) return product.variants.first.prix;
    return product.prixOriginal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = product.isAvailable;
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: available ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: scheme.surfaceContainerHighest,
                      image: product.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(product.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product.imageUrl == null
                        ? Center(
                            child: Icon(
                              Icons.fastfood,
                              size: 40,
                              color: scheme.outline,
                            ),
                          )
                        : null,
                  ),
                  if (!available)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Épuisé',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else if (product.madeToOrder)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Sur commande',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else if (product.variants.length > 1)
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
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatPrice(getDisplayPrice()),
                          style: TextStyle(
                            color: available ? scheme.primary : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (available)
                          InkWell(
                            onTap: () => _addToCart(context, ref),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Épuisé',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Future<void> _addToCart(BuildContext context, WidgetRef ref) async {
    if (product.variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce produit n\'a pas de variante sélectionnable.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final variantId = product.variants.first.id;
    try {
      final added = await addToCartSafely(
        context: context,
        ref: ref,
        variantId: variantId,
        productMadeToOrder: product.madeToOrder,
        productName: product.name,
      );
      if (!added) return;
      AnalyticsService.logAddToCart(
        productId: product.id,
        productName: product.name,
        price: product.variants.first.prix,
        quantity: 1,
        restaurantId: product.restaurantId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('${product.name} ajouté au panier')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

// ─── Horaires d'ouverture ──────────────────────────────────────────────────

class _OperatingHoursSection extends StatefulWidget {
  final List<OperatingHours> operatingHours;

  const _OperatingHoursSection({required this.operatingHours});

  @override
  State<_OperatingHoursSection> createState() => _OperatingHoursSectionState();
}

class _OperatingHoursSectionState extends State<_OperatingHoursSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DayOfWeek.today;
    final todayHours =
        widget.operatingHours.where((h) => h.dayOfWeek == today).toList();
    final sortedHours = List<OperatingHours>.from(widget.operatingHours)
      ..sort((a, b) => a.dayOfWeek.index.compareTo(b.dayOfWeek.index));

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.purple,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Horaires',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          todayHours.isNotEmpty
                              ? todayHours.first.isClosed
                                  ? 'Fermé aujourd\'hui'
                                  : '${todayHours.first.openTime} - ${todayHours.first.closeTime}'
                              : 'Non renseigné',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.outline,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: sortedHours.map((hours) {
                  final isToday = hours.dayOfWeek == today;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            hours.dayOfWeek.shortLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (isToday)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            hours.isClosed
                                ? 'Fermé'
                                : '${hours.openTime} - ${hours.closeTime}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: hours.isClosed
                                  ? scheme.error
                                  : isToday
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
