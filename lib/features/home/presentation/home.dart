import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/favoris/application/restaurant_favorites_provider.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/presentation/notifications_history_screen.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/star_rating.dart';
import 'package:lilia_app/models/restaurant.dart';

import '../../../routing/app_route_enum.dart';
import '../data/remote/restaurant_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  // Liste des bannières pour le slider
  final List<String> _bannerImages = [
    'assets/images/banner.png',
    'assets/images/banner.png',
    'assets/images/banner.png',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final restaurantsAsync = ref.watch(restaurantsListProvider);
    final notificationHistory = ref.watch(notificationHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Lilia Food'),
        actions: [
          notificationHistory.when(
            data: (notifications) => Badge(
              label: Text(notifications.length.toString()),
              isLabelVisible: notifications.isNotEmpty,
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none, color: Colors.black),
              ),
            ),
            loading: () => IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none, color: Colors.black),
            ),
            error: (_, _) => IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined, color: Colors.red),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantsListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Section Slider d'annonces
              _buildAnnouncementSlider(),
              const SizedBox(height: 24),
              // Section Liste des restaurants
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Nos Restaurants',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              _buildRestaurantsList(restaurantsAsync),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementSlider() {
    final imageSliders = _bannerImages
        .asMap()
        .entries
        .map(
          (entry) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 5.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    entry.value,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  // Overlay gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();

    return Column(
      children: [
        CarouselSlider(
          items: imageSliders,
          carouselController: _carouselController,
          options: CarouselOptions(
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: true,
            aspectRatio: 2.0,
            viewportFraction: 0.9,
            onPageChanged: (index, reason) {
              setState(() {
                _currentSlide = index;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        // Indicateurs de page
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _bannerImages.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () => _carouselController.animateToPage(entry.key),
              child: Container(
                width: _currentSlide == entry.key ? 24.0 : 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentSlide == entry.key
                      ? Theme.of(context).primaryColor
                      : Colors.grey.withValues(alpha: 0.4),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRestaurantsList(
    AsyncValue<List<RestaurantSummary>> restaurantsAsync,
  ) {
    return restaurantsAsync.when(
      data: (restaurants) {
        if (restaurants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.restaurant, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun restaurant disponible',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: restaurants.length,
          itemBuilder: (context, index) {
            final restaurant = restaurants[index];
            final restaurantId = restaurants[index].id;
            return _RestaurantCard(
              restaurant: restaurant,
              restaurantId: restaurantId,
            );
          },
        );
      },
      loading: () => const BuildLoadingState(),
      error: (err, stack) => BuildErrorState(
        err,
        onRetry: () => ref.invalidate(restaurantsListProvider),
      ),
    );
  }
}

class _RestaurantCard extends ConsumerWidget {
  final RestaurantSummary restaurant;
  final String restaurantId;

  const _RestaurantCard({required this.restaurant, required this.restaurantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isRestaurantFavoriteProvider(restaurant.id));

    return Opacity(
      // Réduire l'opacité si le restaurant est fermé
      opacity: restaurant.isOpen ? 1.0 : 0.7,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: InkWell(
          onTap: () {
            context.goNamed(
              AppRoutes.restaurantDetail.routeName,
              pathParameters: {'id': restaurant.id},
              extra: {'restaurantName': restaurant.name},
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du restaurant avec badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: restaurant.imageUrl != null
                        ? Image.network(
                            restaurant.imageUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            height: 150,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.restaurant,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                  // Badge Ouvert/Fermé en haut à gauche
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: restaurant.isOpen ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            restaurant.isOpen
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            restaurant.isOpen ? 'Ouvert' : 'Fermé',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bouton favori en haut à droite
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(restaurantFavoritesProvider.notifier)
                              .toggleFavorite(restaurant);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFavorite
                                    ? '${restaurant.name} retiré des favoris'
                                    : '${restaurant.name} ajouté aux favoris',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Temps de livraison en bas à droite
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            restaurant.deliveryTimeFormatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
                padding: const EdgeInsets.all(12),
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
                              fontSize: 18,
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

                    // Spécialités (chips)
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
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              specialty.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Adresse et infos livraison
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurant.address,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Infos de livraison (frais + minimum)
                    Row(
                      children: [
                        // Frais de livraison
                        Icon(
                          Icons.delivery_dining,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.fixedDeliveryFee.toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Minimum de commande
                        if (restaurant.minimumOrderAmount > 0) ...[
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Min. ${restaurant.minimumOrderAmount.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Description (si disponible)
                    if (restaurant.description != null &&
                        restaurant.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        restaurant.description!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
