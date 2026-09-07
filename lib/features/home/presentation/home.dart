import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/banner_shimmer.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/presentation/notifications_history_screen.dart';
import 'package:lilia_app/models/banner.dart';
import 'package:lilia_app/models/restaurant.dart';

import 'package:lilia_app/core/update/app_update_dialog.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';

import '../data/remote/banner_controller.dart';
import '../data/remote/home_controller.dart';
import '../data/remote/restaurant_controller.dart';
import 'widgets/popular_dishes_section.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/section_header.dart';
import 'widgets/vendor_type_filter_bar.dart';

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
  bool _updateDialogShown = false;
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

    // Vérification de mise à jour de l'application (bloquante ou optionnelle)
    ref.listen<AsyncValue<AppUpdateInfo>>(appUpdateInfoProvider, (previous, next) {
      next.whenData((info) async {
        if (!mounted || _updateDialogShown) return;
        final service = ref.read(appUpdateServiceProvider);

        if (info.isMandatory) {
          _updateDialogShown = true;
          AppUpdateDialog.showMandatory(context, info, service);
        } else if (info.isOptional) {
          final versionKey =
              info.latestAvailableVersion?.toString() ?? 'latest';
          final shouldPrompt =
              await service.shouldPromptOptionalUpdate(versionKey);
          if (shouldPrompt && mounted && !_updateDialogShown) {
            _updateDialogShown = true;
            if (context.mounted) {
              AppUpdateDialog.showOptional(context, info, service);
            }
          }
        }
      });
    });
    // LIL-117 : on consomme désormais le marketplace /vendors avec filtre
    // par VendorType (chips au-dessus). vendorsList rebuild auto quand le
    // filtre change. /restaurants reste compatible mais on a tout en
    // marketplace approuvé-actif via /vendors.
    final restaurantsAsync = ref.watch(vendorsListProvider);
    final currentFilter = ref.watch(marketplaceFilterProvider);
    final notificationHistory = ref.watch(notificationHistoryProvider);
    final bannersAsync = ref.watch(bannersListProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Lilia Food',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          _buildNotificationButton(notificationHistory),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vendorsListProvider);
            ref.invalidate(restaurantsListProvider);
            ref.invalidate(bannersListProvider);
            ref.invalidate(popularProductsProvider);
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

                // Le rail « catégories » a été RETIRÉ (septembre 2026).
                //
                // Il affichait la table `Category`, alors globale, avec une
                // icône devinée par correspondance de chaîne — et son `onTap`
                // ne faisait qu'un log analytics : les chips ne menaient nulle
                // part, y compris les quatre catégories vides de la production.
                // Une catégorie appartient désormais à un vendeur ; la
                // découverte transverse passe par `vendorType`, qui a sa propre
                // navigation.

                // 2. Slider promotions (existant)
                _buildSimpleSlider(bannersAsync),

                const SizedBox(height: 20),

                // 4. Plats Populaires
                const SectionHeader(title: 'Plats Populaires'),
                const SizedBox(height: 12),
                const PopularDishesSection(),

                const SizedBox(height: 20),

                // 7. Marketplace (LIL-117) : filtre vendor type + liste
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentFilter == null
                            ? 'Tous les vendeurs'
                            : currentFilter.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${restaurantsAsync.value?.length ?? 0} disponibles',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Chips de filtre vendor type
                const VendorTypeFilterBar(),

                const SizedBox(height: 12),

                // Liste des restaurants/vendeurs filtrés
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
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const NotificationsHistoryScreen(),
              ),
            );
          },
          icon: const Icon(Icons.notifications_outlined),
        ),
      ),
      loading: () => const IconButton(
        tooltip: 'Notifications',
        onPressed: null,
        icon: Icon(Icons.notifications_outlined),
      ),
      error: (_, _) => const IconButton(
        tooltip: 'Notifications',
        onPressed: null,
        icon: Icon(Icons.notifications_outlined, color: Colors.red),
      ),
    );
  }

  Widget _buildSimpleSlider(AsyncValue<List<AppBanner>> bannersAsync) {
    return bannersAsync.when(
      data: (apiBanners) {
        if (apiBanners.isNotEmpty) {
          return _buildSliderContent(
            itemCount: apiBanners.length,
            imageBuilder: (index) => AppCachedImage(
              imageUrl: apiBanners[index].imageUrl,
              fit: BoxFit.cover,
              errorWidget: Image.asset(
                'assets/images/banner.png',
                fit: BoxFit.cover,
              ),
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
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
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
            // Entrée en cascade pour les premières cartes (visibles d'emblée) ;
            // au-delà, simple fondu/glissé au scroll (évite les longs délais).
            return RestaurantCard(
              restaurant: restaurant,
              restaurantId: restaurant.id,
            ).staggeredIn(index < 6 ? index : 0);
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
