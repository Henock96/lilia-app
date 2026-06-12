import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/common_widgets/image_gallery.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/menu.dart';
import '../../../models/produit.dart';
import '../../../models/restaurant.dart';
import '../../../models/vendor_type.dart';
import '../../../routing/app_route_enum.dart';
import '../../cart/presentation/cart_mode_conflict_dialog.dart';
import '../data/remote/restaurant_controller.dart';
import 'widgets/menu_card.dart';
import 'widgets/vendor_type_badge.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';

/// Écran de détail vendeur (LIL-117 — refonte UI).
///
/// Layout :
///   1. Hero image plein écran avec back/menus/share/reviews floating
///      (l'icône menus n'apparaît que si le vendeur a des menus du jour actifs)
///   2. Carte d'identité : statut ouvert/fermé + spécialités (même ligne) + note
///   3. Story « À propos » pliable + certifications/note de production (si VendorProfile)
///   4. Quick info livraison (temps, frais, minimum)
///   5. Horaires (collapsible)
///   6. Bouton "Appeler"
///   7. Search + tabs catégories
///   8. Produits groupés par catégorie
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
          hasMenus: restaurant.menus.isNotEmpty,
          onMenus: () => _showMenusSheet(restaurant.menus),
          onShare: _shareRestaurant,
          onReviews: () => context.pushNamed(
            AppRoutes.reviews.routeName,
            extra: {
              'restaurantId': widget.restaurantId,
              'restaurantName': restaurant.name,
            },
          ),
        ),

        // 2. Carte d'identité (statut ouvert/fermé + spécialités + note)
        SliverToBoxAdapter(
          child: _VendorIdentityCard(restaurant: restaurant),
        ),

        // 3. Story + profil enrichi (HOME_COOK/BAKERY surtout)
        if (restaurant.vendorProfile != null &&
            !restaurant.vendorProfile!.isEmpty)
          SliverToBoxAdapter(
            child: _VendorProfileSection(profile: restaurant.vendorProfile!),
          ),

        // 4. Quick info livraison
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

        // 7. Section produits — header
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

        // 8. Search produit
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

        // 9. Onglets catégories
        if (categories.isNotEmpty)
          SliverToBoxAdapter(
            child: _CategoryTabs(
              categories: categories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (c) => setState(() => _selectedCategory = c),
            ),
          ),

        // 10. Liste des produits
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

  /// Affiche les menus du jour dans un bottom sheet. Les menus sont déjà
  /// embarqués dans le vendeur (`restaurant.menus`) — aucune requête réseau.
  void _showMenusSheet(List<MenuDuJour> menus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Menus du Jour',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${menus.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: menus.length,
                    itemBuilder: (context, index) {
                      final menu = menus[index];
                      return MenuCard(
                        menu: menu,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.pushNamed(
                            AppRoutes.menuDetail.routeName,
                            extra: menu,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      context.showSnack('Numéro de téléphone non disponible');
      return;
    }
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      context.showSnack('Impossible d\'ouvrir l\'application téléphone');
    }
  }
}

// ─── Hero AppBar ────────────────────────────────────────────────────────────

class _VendorHeroAppBar extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasMenus;
  final VoidCallback onMenus;
  final VoidCallback onShare;
  final VoidCallback onReviews;

  const _VendorHeroAppBar({
    required this.restaurant,
    required this.hasMenus,
    required this.onMenus,
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
        // Accès aux menus du jour — visible seulement si le vendeur en a.
        if (hasMenus)
          _circleButton(
            context,
            icon: Icons.restaurant_menu,
            onTap: onMenus,
          ),
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
            ImageGallery(
              urls: restaurant.galleryUrls,
              placeholder: _placeholder(scheme),
              heroTag: 'resto-img-${restaurant.id}',
              // Nom + adresse superposés en bas → dots placés en haut.
              indicatorAlignment: Alignment.topCenter,
              indicatorPadding: const EdgeInsets.only(top: 70),
            ),
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
    final hasRating =
        restaurant.averageRating != null && restaurant.averageRating! > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut ouvert/fermé + spécialités sur la même ligne (le Wrap
          // passe à la ligne automatiquement si les chips débordent).
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusChip(),
                for (final s in restaurant.specialties) _specialtyChip(context, s),
              ],
            ),
          ),
          if (hasRating) ...[
            const SizedBox(width: 8),
            _rating(context),
          ],
        ],
      ),
    );
  }

  Widget _statusChip() {
    final open = restaurant.isOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (open ? Colors.green : Colors.red).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: open ? Colors.green : Colors.red, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open ? Icons.check_circle : Icons.cancel,
            color: open ? Colors.green : Colors.red,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            open ? 'Ouvert' : 'Fermé',
            style: TextStyle(
              color: open ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _specialtyChip(BuildContext context, Specialty specialty) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        specialty.name,
        style: TextStyle(
          fontSize: 12,
          color: scheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _rating(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Aligne visuellement la note avec la première ligne de chips.
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
          const SizedBox(width: 2),
          Text(
            restaurant.averageRating!.toStringAsFixed(1),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (restaurant.totalReviews != null)
            Text(
              ' (${restaurant.totalReviews})',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// ─── Profil enrichi (story + certifications + production note) ──────────────

class _VendorProfileSection extends StatefulWidget {
  final VendorProfile profile;

  const _VendorProfileSection({required this.profile});

  @override
  State<_VendorProfileSection> createState() => _VendorProfileSectionState();
}

class _VendorProfileSectionState extends State<_VendorProfileSection> {
  // Story repliée par défaut : les produits restent rapidement accessibles.
  bool _storyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final scheme = Theme.of(context).colorScheme;
    final hasStory = profile.story != null && profile.story!.isNotEmpty;
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
            if (hasStory) ...[
              InkWell(
                onTap: () =>
                    setState(() => _storyExpanded = !_storyExpanded),
                child: Row(
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
                    const Spacer(),
                    Icon(
                      _storyExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profile.story!,
                style: const TextStyle(fontSize: 13.5, height: 1.45),
                maxLines: _storyExpanded ? null : 2,
                overflow: _storyExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
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
            ).fadeSlideIn(),
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
      context.showSnack('Ce produit n\'a pas de variante sélectionnable.');
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
        context.showSuccessSnack('${product.name} ajouté au panier');
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorSnack(e.toString());
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
