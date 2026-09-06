import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/features/favoris/application/restaurant_favorites_provider.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/star_rating.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/services/analytics_service.dart';
import '../vendor_type_badge.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';

class RestaurantCard extends ConsumerWidget {
  final RestaurantSummary restaurant;
  final String restaurantId;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.restaurantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isRestaurantFavoriteProvider(restaurant.id));
    final theme = Theme.of(context);

    return Semantics(
      // L'ouverture/fermeture n'était signalée que visuellement (opacité 0.6 +
      // badge coloré) : invisible pour un lecteur d'écran.
      label: restaurant.isOpen
          ? '${restaurant.name}, ouvert'
          : '${restaurant.name}, fermé',
      button: true,
      child: Opacity(
        opacity: restaurant.isOpen ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.goNamed(
                  AppRoutes.restaurantDetail.routeName,
                  pathParameters: {'id': restaurant.id},
                  extra: {'restaurantName': restaurant.name},
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image du restaurant avec badges
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: restaurant.thumbnailUrl != null
                            ? Hero(
                                tag: 'resto-img-${restaurant.id}',
                                child: AppCachedImage(
                                  imageUrl: restaurant.thumbnailUrl!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorIcon: Icons.restaurant,
                                  // Décorative : le nom du vendeur est déjà
                                  // annoncé par le label de la carte.
                                  semanticLabel: null,
                                ),
                              )
                            : Container(
                                height: 150,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.restaurant,
                                  size: 48,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                      ),
                      // Badges en haut à gauche : ouvert/fermé + vendor type
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: restaurant.isOpen
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                restaurant.isOpen ? 'Ouvert' : 'Fermé',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Vendor type (LIL-117) — masqué pour RESTAURANT
                            VendorTypeBadge(vendorType: restaurant.vendorType),
                          ],
                        ),
                      ),
                      // Bouton favori
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Semantics(
                          button: true,
                          label: isFavorite
                              ? 'Retirer ${restaurant.name} des favoris'
                              : 'Ajouter ${restaurant.name} aux favoris',
                          child: GestureDetector(
                            onTap: () {
                              ref
                                  .read(restaurantFavoritesProvider.notifier)
                                  .toggleFavorite(restaurant);
                              AnalyticsService.trackFavoriteToggle(
                                restaurantId: restaurant.id,
                                restaurantName: restaurant.name,
                                isFavorite: !isFavorite,
                              );
                              context.showSnack(
                                isFavorite
                                    ? '${restaurant.name} retiré des favoris'
                                    : '${restaurant.name} ajouté aux favoris',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.9,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite
                                    ? Colors.red
                                    : theme.colorScheme.outline,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Temps de livraison
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.deliveryTimeFormatted,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Informations du restaurant
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom et note
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                restaurant.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (restaurant.averageRating != null &&
                                restaurant.totalReviews != null &&
                                restaurant.totalReviews! > 0)
                              RatingBadge(
                                rating: restaurant.averageRating!,
                                reviewCount: restaurant.totalReviews!,
                              ),
                          ],
                        ),

                        // SpÃƒÆ’Ã‚Â©cialitÃƒÆ’Ã‚Â©s
                        if (restaurant.specialties.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: restaurant.specialties.take(3).map((
                              specialty,
                            ) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  specialty.name,
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

                        const SizedBox(height: 10),

                        // Adresse et infos livraison
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                restaurant.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Frais de livraison et minimum
                        Row(
                          children: [
                            Icon(
                              Icons.delivery_dining_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatPrice(restaurant.fixedDeliveryFee),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (restaurant.minimumOrderAmount > 0) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Min. ${restaurant.minimumOrderAmount.toStringAsFixed(0)} FCFA',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
