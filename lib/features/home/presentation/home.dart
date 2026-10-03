import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:lilia_app/features/home/data/brazzaville_weather.dart';
import 'package:lilia_app/features/home/presentation/widgets/home_greeting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/common_widgets/stale_data_banner.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/banner_shimmer.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/models/banner.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/models/restaurant.dart';

import 'package:lilia_app/core/update/app_update_gate.dart';

import '../data/remote/banner_controller.dart';
import '../data/remote/home_controller.dart';
import '../data/remote/restaurant_controller.dart';
import 'widgets/available_now_section.dart';
import 'widgets/open_now_rail.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/vendor_type_filter_bar.dart';
import 'package:lilia_app/utils/async_value_ui.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// `AppUpdateGate` : vérification de mise à jour (bloquante ou facultative).
// L'accueil est le premier écran stable après le démarrage : c'est là que le
// parc installé apprend qu'il est périmé.
class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin, AppUpdateGate {
  @override
  bool get wantKeepAlive => true;

  /// Bannière affichée. Un `ValueNotifier` et non un champ + `setState` :
  /// le carrousel tourne toutes les 4 s, et chaque `setState` reconstruisait
  /// l'écran d'accueil entier — dont la liste des vendeurs, construite en
  /// `shrinkWrap` donc intégralement mise en page — pour déplacer un point.
  final ValueNotifier<int> _currentSlide = ValueNotifier(0);

  /// Dernier chargement **réussi** de la liste des vendeurs : pour quel
  /// filtre, et quand (P3-12).
  ///
  /// Après un rechargement raté, Riverpod garde la valeur précédente dans
  /// l'erreur — mais `when` affichait l'erreur **à la place** de la liste :
  /// hors ligne, l'accueil passait à « 0 disponibles ». On garde désormais la
  /// liste, avec un bandeau daté. Le filtre est mémorisé parce que la valeur
  /// retenue est celle du dernier succès : après un changement de puce raté,
  /// ce serait la liste d'un **autre** filtre sous le nouveau titre.
  ({VendorType? filter, DateTime at})? _vendorsLoaded;

  @override
  void dispose() {
    _currentSlide.dispose();
    super.dispose();
  }

  final CarouselSliderController _carouselController =
      CarouselSliderController();

  /// Cible de « Voir toutes les boutiques » (repli de « Disponible
  /// maintenant »).
  final GlobalKey _allVendorsKey = GlobalKey();

  void _scrollToAllVendors() {
    final target = _allVendorsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.base,
      curve: AppMotion.curve,
    );
  }

  // Contenu éditorial utilisable même si l'API ou les images sont indisponibles.
  static const List<Map<String, String>> _defaultBanners = [
    {'title': 'Bienvenue sur Lilia Food'},
    // « Livraison rapide » promettait un délai que rien ne garantit.
    {'title': 'Livraison ou retrait'},
    {'title': 'Découvrez nos menus'},
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // LIL-117 : on consomme désormais le marketplace /vendors avec filtre
    // par VendorType (chips au-dessus). vendorsList rebuild auto quand le
    // filtre change. /restaurants reste compatible mais on a tout en
    // marketplace approuvé-actif via /vendors.
    final restaurantsAsync = ref.watch(vendorsListProvider);
    final currentFilter = ref.watch(marketplaceFilterProvider);
    ref.listen(vendorsListProvider, (_, next) {
      if (next.hasValue && !next.hasError && !next.isLoading) {
        _vendorsLoaded = (
          filter: ref.read(marketplaceFilterProvider),
          at: DateTime.now(),
        );
      }
    });
    // Premier succès déjà là au montage (cache) : l'écouteur ne l'a pas vu.
    if (_vendorsLoaded == null &&
        restaurantsAsync.hasValue &&
        !restaurantsAsync.hasError &&
        !restaurantsAsync.isLoading) {
      _vendorsLoaded = (filter: currentFilter, at: DateTime.now());
    }
    final staleVendors = _staleVendors(restaurantsAsync, currentFilter);
    final notificationHistory = ref.watch(notificationHistoryProvider);
    final bannersAsync = ref.watch(bannersListProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const HomeGreeting(),
        actions: [
          _buildNotificationButton(
            notificationHistory,
            ref.watch(unreadNotificationCountProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vendorsListProvider);
            ref.invalidate(restaurantsListProvider);
            ref.invalidate(bannersListProvider);
            ref.invalidate(availableNowProvider);
            ref.invalidate(brazzavilleWeatherProvider);
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

                // 2. Filtre par type de vendeur — remonté : il gouverne les
                // trois sections suivantes (UI Refresh, ordre §9.1).
                const VendorTypeFilterBar(),

                const SizedBox(height: 20),

                // 3. Ouvert maintenant — dérivé de la liste des vendeurs,
                // aucun appel réseau ; disparaît si rien n'est ouvert.
                const OpenNowRail(),

                // 4. Disponible maintenant — `GET /products/available-now`.
                AvailableNowSection(onSeeAllVendors: _scrollToAllVendors),

                // 5. Bannières, compactées : l'éditorial passe après ce qui
                // se commande.
                _buildSimpleSlider(bannersAsync),

                const SizedBox(height: 20),

                // 6. Toutes les boutiques.
                Padding(
                  key: _allVendorsKey,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Semantics(
                          header: true,
                          child: Text(
                            currentFilter == null
                                ? 'Toutes les boutiques'
                                : currentFilter.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        // Rien tant qu'aucune liste n'est affichée : « 0
                        // disponibles » pendant une panne affirmait qu'il n'y
                        // avait aucune boutique.
                        restaurantsAsync.hasValue &&
                                (!restaurantsAsync.hasError ||
                                    staleVendors != null)
                            ? _affiches(restaurantsAsync.value!.length)
                            : '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

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

  /// Badge = notifications **non lues** (P3-07), plafonné à « 9+ ».
  Widget _buildNotificationButton(
    AsyncValue<List<dynamic>> notificationHistory,
    int unread,
  ) {
    return notificationHistory.when(
      data: (_) => Badge(
        label: Text(unread > 9 ? '9+' : '$unread'),
        isLabelVisible: unread > 0,
        child: IconButton(
          tooltip: unread > 0
              ? 'Notifications, $unread non lue${unread > 1 ? 's' : ''}'
              : 'Notifications',
          onPressed: () => context.pushNamed(AppRoutes.notifications.routeName),
          icon: const Icon(Icons.notifications_outlined),
        ),
      ),
      loading: () => const IconButton(
        tooltip: 'Notifications',
        onPressed: null,
        icon: Icon(Icons.notifications_outlined),
      ),
      // L'historique est local : illisible, il n'empêche pas d'ouvrir l'écran
      // (qui dira pourquoi) — l'icône rouge sans action n'expliquait rien.
      error: (_, _) => IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.pushNamed(AppRoutes.notifications.routeName),
        icon: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  Widget _buildSimpleSlider(AsyncValue<List<AppBanner>> bannersAsync) {
    return bannersAsync.whenUi(
      data: (apiBanners) {
        if (apiBanners.isNotEmpty) {
          return _buildSliderContent(
            itemCount: apiBanners.length,
            imageBuilder: (index) => AppCachedImage.framed(
              imageUrl: apiBanners[index].imageUrl,
              errorWidget: _bannerFallback(),
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
      imageBuilder: (_) => _bannerFallback(),
      titleBuilder: (index) => _defaultBanners[index]['title']!,
    );
  }

  /// Repli local des bannières : API en panne, liste vide ou image distante
  /// en échec. Aucun asset — `assets/images/banner.png`, référencé ici
  /// jusqu'au 27/09/2026, n'a jamais existé : la panne de l'API se doublait
  /// d'une erreur de chargement d'asset.
  Widget _bannerFallback() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.tertiary,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Icon(
        Icons.restaurant_rounded,
        size: 54,
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .8),
      ),
    ),
  );

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
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: true,
            // 2.2 → 3.3 : hauteur ÷ 1,5 (UI Refresh).
            aspectRatio: 3.3,
            viewportFraction: 0.92,
            // « Réduire les animations » (iOS) / « Supprimer les animations »
            // (Android) : un contenu qui défile seul est justement ce que ce
            // réglage demande d'arrêter. Le balayage manuel reste possible.
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onPageChanged: (index, reason) => _currentSlide.value = index,
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
        ValueListenableBuilder<int>(
          valueListenable: _currentSlide,
          builder: (context, current, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(itemCount, (index) {
              final isActive = current == index;
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
        ),
      ],
    );
  }

  static String _affiches(int n) => '$n affiché${n > 1 ? 's' : ''}';

  /// Date du dernier chargement réussi **pour ce filtre**, si la liste
  /// affichée est une liste conservée après un échec ; `null` sinon.
  DateTime? _staleVendors(
    AsyncValue<List<RestaurantSummary>> async,
    VendorType? filter,
  ) {
    final loaded = _vendorsLoaded;
    if (!async.hasError || !async.hasValue || loaded == null) return null;
    return loaded.filter == filter ? loaded.at : null;
  }

  Widget _buildRestaurantsList(
    AsyncValue<List<RestaurantSummary>> restaurantsAsync,
  ) {
    final filter = ref.read(marketplaceFilterProvider);
    final staleAt = _staleVendors(restaurantsAsync, filter);
    if (staleAt != null) {
      return Column(
        children: [
          StaleDataBanner(
            loadedAt: staleAt,
            onRetry: () => ref.invalidate(vendorsListProvider),
          ),
          _vendorsListView(restaurantsAsync.value!),
        ],
      );
    }
    return restaurantsAsync.whenUi(
      data: (restaurants) {
        if (restaurants.isEmpty) {
          // Liste réellement vide (réponse du serveur) — distincte d'une
          // panne, qui passe par `BuildErrorState`. Avec un filtre, on
          // propose le geste qui sort de l'impasse.
          final cs = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 64,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    filter == null
                        ? 'Aucune boutique disponible pour le moment'
                        : 'Aucune boutique « ${filter.label} » pour le moment',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                  ),
                  if (filter != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.read(marketplaceFilterProvider.notifier).reset(),
                      child: const Text('Voir toutes les boutiques'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return _vendorsListView(restaurants);
      },
      loading: () => const BuildLoadingState(),
      // ⚠️ `vendorsListProvider`, celui que l'écran observe. Le bouton
      // invalidait `restaurantsListProvider`, dont `vendorsList` ne dépend
      // pas : « Réessayer » ne relançait rien.
      error: (err, stack) => BuildErrorState(
        err,
        onRetry: () => ref.invalidate(vendorsListProvider),
      ),
    );
  }

  Widget _vendorsListView(List<RestaurantSummary> restaurants) {
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
  }
}
