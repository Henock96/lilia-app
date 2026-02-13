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
import 'package:lilia_app/models/banner.dart';
import 'package:lilia_app/models/restaurant.dart';

import '../../../routing/app_route_enum.dart';
import '../data/remote/banner_controller.dart';
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

  // Bannières par défaut (fallback si aucune bannière API)
  static const List<Map<String, String>> _defaultBanners = [
    {'image': 'assets/images/banner.png', 'title': 'Bienvenue sur Lilia Food'},
    {'image': 'assets/images/banner.png', 'title': 'Livraison rapide'},
    {'image': 'assets/images/banner.png', 'title': 'Nouveaux restaurants'},
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final restaurantsAsync = ref.watch(restaurantsListProvider);
    final notificationHistory = ref.watch(notificationHistoryProvider);
    final bannersAsync = ref.watch(bannersListProvider);
    //final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lilia Food',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          _buildNotificationButton(notificationHistory),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantsListProvider);
          ref.invalidate(bannersListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Slider d'annonces dynamique
              _buildSimpleSlider(bannersAsync),

              const SizedBox(height: 24),

              // Titre de la section restaurants
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nos Restaurants',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${restaurantsAsync.value?.length ?? 0} disponibles',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Liste des restaurants
              _buildRestaurantsList(restaurantsAsync),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(
    AsyncValue<List<dynamic>> notificationHistory,
  ) {
    return notificationHistory.when(
      data: (notifications) => Badge(
        label: Text(notifications.length.toString()),
        isLabelVisible: notifications.isNotEmpty,
        backgroundColor: Colors.red,
        child: IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationsHistoryScreen(),
              ),
            );
          },
          icon: Icon(Icons.notifications_outlined, color: Colors.grey[700]),
        ),
      ),
      loading: () => IconButton(
        onPressed: () {},
        icon: Icon(Icons.notifications_outlined, color: Colors.grey[700]),
      ),
      error: (_, _) => IconButton(
        onPressed: () {},
        icon: const Icon(Icons.notifications_outlined, color: Colors.red),
      ),
    );
  }

  Widget _buildSimpleSlider(AsyncValue<List<AppBanner>> bannersAsync) {
    return bannersAsync.when(
      data: (apiBanners) {
        // Si des bannières API existent, les utiliser ; sinon fallback
        if (apiBanners.isNotEmpty) {
          return _buildSliderContent(
            itemCount: apiBanners.length,
            imageBuilder: (index) => Image.network(
              apiBanners[index].imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/banner.png',
                fit: BoxFit.cover,
              ),
            ),
            titleBuilder: (index) => apiBanners[index].title,
          );
        }
        return _buildFallbackSlider();
      },
      loading: () => _buildFallbackSlider(),
      error: (_, _) => _buildFallbackSlider(),
    );
  }

  Widget _buildFallbackSlider() {
    return _buildSliderContent(
      itemCount: _defaultBanners.length,
      imageBuilder: (index) => Image.asset(
        _defaultBanners[index]['image']!,
        fit: BoxFit.cover,
      ),
      titleBuilder: (index) => _defaultBanners[index]['title']!,
    );
  }

  Widget _buildSliderContent({
    required int itemCount,
    required Widget Function(int index) imageBuilder,
    required String Function(int index) titleBuilder,
  }) {
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: itemCount,
          carouselController: _carouselController,
          options: CarouselOptions(
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: true,
            aspectRatio: 2.2,
            viewportFraction: 0.92,
            onPageChanged: (index, reason) {
              setState(() {
                _currentSlide = index;
              });
            },
          ),
          itemBuilder: (context, index, realIndex) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageBuilder(index),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Text(
                        titleBuilder(index),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(itemCount, (index) {
            final isActive = _currentSlide == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
              ),
            );
          }),
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
            return _RestaurantCard(
              restaurant: restaurant,
              restaurantId: restaurant.id,
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
    final theme = Theme.of(context);

    return Opacity(
      opacity: restaurant.isOpen ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                    // Badge Ouvert/Fermé
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: restaurant.isOpen ? Colors.green : Colors.red,
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
                    ),
                    // Bouton favori
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
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
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                            size: 20,
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

                      // Spécialités
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
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurant.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${restaurant.fixedDeliveryFee.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (restaurant.minimumOrderAmount > 0) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 14,
                              color: Colors.grey[500],
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
