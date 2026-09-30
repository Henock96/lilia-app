import 'dart:async';
import 'package:lilia_app/common_widgets/lilia_badge.dart';

import 'package:lilia_app/features/home/domain/opening_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/async_value_ui.dart';

import '../../../models/produit.dart';
import '../../../models/restaurant.dart';
import '../../../routing/app_route_enum.dart';
import '../data/remote/home_controller.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';

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
              tooltip: 'Fermer',
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

    return resultsAsync.whenUi(
      data: (results) {
        // ⚠️ Aucun événement de recherche ici, et pour deux raisons.
        //
        // L'appel précédent envoyait `query` — le texte saisi par le client,
        // que le contrat interdit d'envoyer (contenu libre : il contient
        // régulièrement un nom, parfois un numéro).
        //
        // Il était de surcroît placé dans un `build` : chaque reconstruction de
        // l'écran — clavier, thème, arrivée d'une réponse — le renvoyait.
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Aucun résultat pour "$_query"',
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
                (r) => _SearchRestaurantTile(restaurant: r).fadeSlideIn(),
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
              ...results.products.map(
                (p) => _SearchProductTile(product: p).fadeSlideIn(),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => BuildErrorState(
        err,
        onRetry: () => ref.invalidate(searchResultsProvider(_query)),
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
          child: restaurant.thumbnailUrl != null
              ? AppCachedImage(
                  imageUrl: restaurant.thumbnailUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: _placeholderBox(
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
                    // Le libellé à côté porte l'information ; la pastille
                    // n'est qu'un rappel visuel.
                    color: restaurant.isOpen == true
                        ? cs.successText
                        : cs.error,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  openingLabel(
                    restaurant.isOpen,
                    restaurant.pausedUntil,
                    nextOpeningAt: restaurant.nextOpeningAt,
                    nextOpeningServed: restaurant.nextOpeningServed,
                  ),
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
          context.pushNamed(
            AppRoutes.productDetail.routeName,
            pathParameters: {'productId': product.id},
            extra: product,
          );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.thumbnailUrl != null
              ? AppCachedImage(
                  imageUrl: product.thumbnailUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: _placeholderBox(cs),
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
              product.priceLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ],
        ),
        trailing: product.isOrderable
            ? QuickAddButton(product: product)
            : LiliaBadge(
              label: product.unavailability?.badge ?? 'Indisponible',
              variant: LiliaBadgeVariant.danger,
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
}
