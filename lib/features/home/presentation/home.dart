import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/banner_shimmer.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/presentation/notifications_history_screen.dart';
import 'package:lilia_app/models/banner.dart';
import 'package:lilia_app/models/restaurant.dart';

import '../data/remote/banner_controller.dart';
import '../data/remote/home_controller.dart';
import '../data/remote/restaurant_controller.dart';
import 'widgets/category_list_widget.dart';
import 'widgets/popular_dishes_section.dart';
import 'widgets/popular_restaurants_section.dart';
import 'widgets/recommendations_section.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/section_header.dart';

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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        //backgroundColor: Colors.white,
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(restaurantsListProvider);
            ref.invalidate(bannersListProvider);
            ref.invalidate(popularProductsProvider);
            ref.invalidate(popularRestaurantsProvider);
            ref.invalidate(recommendationsProvider);
            ref.invalidate(categoriesListProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // 1. Barre de recherche
                const SearchBarWidget(),

                const SizedBox(height: 16),

                // 2. Categories horizontales
                const CategoryListWidget(),

                const SizedBox(height: 16),

                // 3. Slider promotions (existant)
                _buildSimpleSlider(bannersAsync),

                const SizedBox(height: 20),

                // 4. Plats Populaires
                const SectionHeader(title: 'Plats Populaires'),
                const SizedBox(height: 12),
                const PopularDishesSection(),

                const SizedBox(height: 20),

                // 5. Restaurants Populaires
                const SectionHeader(title: 'Restaurants Populaires'),
                const SizedBox(height: 12),
                const PopularRestaurantsSection(),

                // 6. Recommandations (conditionnel, gere en interne)
                const RecommendationsSection(),

                const SizedBox(height: 20),

                // 7. Tous les restaurants (existant)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Restaurants près de vous',
                        style: TextStyle(
                          fontSize: 18,
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

                const SizedBox(height: 12),

                // Liste des restaurants
                _buildRestaurantsList(restaurantsAsync),

                const SizedBox(height: 20),
              ],
            ),
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
        if (apiBanners.isNotEmpty) {
          return _buildSliderContent(
            itemCount: apiBanners.length,
            imageBuilder: (index) => Image.network(
              apiBanners[index].imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Image.asset('assets/images/banner.png', fit: BoxFit.cover),
            ),
            titleBuilder: (index) => apiBanners[index].title,
            hasTitle: (index) =>
                apiBanners[index].title != null &&
                apiBanners[index].title!.isNotEmpty,
          );
        }
        return _buildFallbackSlider();
      },
      loading: () => buildBannerShimmer(),
      error: (_, _) => _buildFallbackSlider(),
    );
  }

  Widget _buildFallbackSlider() {
    return _buildSliderContent(
      itemCount: _defaultBanners.length,
      imageBuilder: (index) =>
          Image.asset(_defaultBanners[index]['image']!, fit: BoxFit.cover),
      titleBuilder: (index) => _defaultBanners[index]['title']!,
    );
  }

  Widget _buildSliderContent({
    required int itemCount,
    required Widget Function(int index) imageBuilder,
    required String? Function(int index) titleBuilder,
    bool Function(int index)? hasTitle,
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
                    if (hasTitle == null || hasTitle(index)) ...[
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
                          titleBuilder(index) ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
            return RestaurantCard(
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
