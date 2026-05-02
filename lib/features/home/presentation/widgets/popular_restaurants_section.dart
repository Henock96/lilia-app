import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/restaurant.dart';
import '../../../../routing/app_route_enum.dart';
import '../../../../services/analytics_service.dart';
import '../../data/remote/home_controller.dart';
import 'shimmer_box.dart';

class PopularRestaurantsSection extends ConsumerWidget {
  const PopularRestaurantsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(popularRestaurantsProvider);

    return restaurantsAsync.when(
      data: (restaurants) {
        if (restaurants.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              return _PopularRestaurantCard(restaurant: restaurants[index]);
            },
          ),
        );
      },
      loading: () => _buildShimmer(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: 150,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: 150,
                  height: 100,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: 110,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: 80,
                  height: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                const Spacer(),
                ShimmerBox(
                  width: 100,
                  height: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PopularRestaurantCard extends StatelessWidget {
  final RestaurantSummary restaurant;

  const _PopularRestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AnalyticsService.logPopularRestaurantTap(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
        );
        context.goNamed(
          AppRoutes.restaurantDetail.routeName,
          pathParameters: {'id': restaurant.id},
          extra: {'restaurantName': restaurant.name},
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: restaurant.isOpen ? 1.0 : 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du restaurant
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: restaurant.imageUrl != null
                        ? Image.network(
                            restaurant.imageUrl!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  // Badge ouvert/ferme
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: restaurant.isOpen ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        restaurant.isOpen ? 'Ouvert' : 'Ferme',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Infos
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Note et temps
                      Row(
                        children: [
                          if (restaurant.averageRating != null &&
                              restaurant.totalReviews != null &&
                              restaurant.totalReviews! > 0) ...[
                            Icon(
                              Icons.star,
                              size: 13,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              restaurant.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            restaurant.deliveryTimeFormatted,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Specialites
                      if (restaurant.specialties.isNotEmpty)
                        Text(
                          restaurant.specialtiesFormatted,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 100,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.restaurant, size: 36, color: Colors.grey),
      ),
    );
  }
}
