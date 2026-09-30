import 'package:flutter/material.dart';
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/stale_data_banner.dart';

import '../../../../models/produit.dart';
import '../../../../routing/app_route_enum.dart';
import '../../data/remote/home_controller.dart';
import 'section_header.dart';
import 'shimmer_box.dart';
import 'package:lilia_app/utils/async_value_ui.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';

/// Hauteur d'une carte « Plat populaire » pour la taille de texte courante.
///
/// Elle était fixée à 220 : dès 1.5× le texte ne tenait plus sous l'image, et
/// à 2× le prix et le « + » disparaissaient (P3-02). Image (110) + textes
/// mis à l'échelle + zone de tap du « + » (48). Jamais sous 220, pour ne rien
/// changer au rendu à 1×.
double popularDishCardHeight(TextScaler scaler) {
  double ligne(double fontSize) => scaler.scale(fontSize) * 1.5;
  final infos =
      12 + // padding vertical
      ligne(13) * 2 + // nom, 2 lignes
      2 +
      ligne(11) + // vendeur
      4 +
      [48.0, ligne(12) * 2].reduce((a, b) => a > b ? a : b); // prix / « + »
  final h = 110 + 2 + infos;
  return h < 220 ? 220 : h;
}

class PopularDishesSection extends ConsumerStatefulWidget {
  const PopularDishesSection({super.key});

  @override
  ConsumerState<PopularDishesSection> createState() =>
      _PopularDishesSectionState();
}

class _PopularDishesSectionState extends ConsumerState<PopularDishesSection> {
  /// Heure du dernier chargement réussi, pour dater une liste conservée.
  DateTime? _loadedAt;

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(popularProductsProvider);
    ref.listen(popularProductsProvider, (_, next) {
      if (next.hasValue && !next.hasError && !next.isLoading) {
        _loadedAt = DateTime.now();
      }
    });
    // Premier succès déjà là au montage (cache) : l'écouteur ne l'a pas vu.
    if (_loadedAt == null &&
        dishesAsync.hasValue &&
        !dishesAsync.hasError &&
        !dishesAsync.isLoading) {
      _loadedAt = DateTime.now();
    }

    // Hors ligne, un rafraîchissement en échec garde la dernière liste :
    // elle reste affichée, datée, comme la liste des vendeurs (P3-12). La
    // section n'a pas de filtre — la liste conservée est donc toujours celle
    // du même contexte. Sans liste antérieure, rien n'est inventé : la
    // section disparaît comme avant.
    final staleAt = _loadedAt;
    if (dishesAsync.hasError &&
        dishesAsync.hasValue &&
        staleAt != null &&
        dishesAsync.value!.isNotEmpty) {
      return _withHeader(
        Column(
          children: [
            StaleDataBanner(
              loadedAt: staleAt,
              onRetry: () => ref.invalidate(popularProductsProvider),
            ),
            _dishesList(context, dishesAsync.value!),
          ],
        ),
      );
    }

    // Section secondaire : vide ou en panne, elle disparaît **avec son titre**
    // — le titre vivait dans l'accueil et restait orphelin au-dessus d'un
    // vide. La liste des vendeurs, elle, garde son message et « Réessayer ».
    return dishesAsync.whenUi(
      data: (dishes) {
        if (dishes.isEmpty) return const SizedBox.shrink();
        return _withHeader(_dishesList(context, dishes));
      },
      loading: () => _withHeader(_buildShimmer()),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _dishesList(BuildContext context, List<Product> dishes) => SizedBox(
    height: popularDishCardHeight(MediaQuery.textScalerOf(context)),
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: dishes.length,
      itemBuilder: (context, index) {
        return _DishCard(
          product: dishes[index],
        ).fadeScaleIn(delay: AppMotion.stagger * index.clamp(0, 5));
      },
    ),
  );

  Widget _withHeader(Widget content) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(title: 'Plats Populaires'),
      const SizedBox(height: 12),
      content,
      const SizedBox(height: 20),
    ],
  );

  Widget _buildShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: 160,
                  height: 110,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: 120,
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
                  width: 70,
                  height: 12,
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

class _DishCard extends ConsumerWidget {
  final Product product;

  const _DishCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAvailable = product.isOrderable;

    return Semantics(
      button: true,
      // L'indisponibilité n'était portée que par `Opacity(0.5)` et un badge
      // rouge : muette pour TalkBack / VoiceOver.
      label: isAvailable
          ? product.name
          : '${product.name}, ${product.unavailability?.badge.toLowerCase() ?? 'indisponible'}',
      enabled: isAvailable,
      child: GestureDetector(
        // Aucun événement ici : ce geste **ouvre** la fiche produit, qui
        // émet `product_view`. En émettre un second sous un autre nom
        // compterait deux fois la même consultation.
        onTap: () => context.pushNamed(
          AppRoutes.productDetail.routeName,
          pathParameters: {'productId': product.id},
          extra: product,
        ),
        child: Container(
          width: 160,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Opacity(
            opacity: isAvailable ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image du plat
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: product.thumbnailUrl != null
                          ? AppCachedImage(
                              imageUrl: product.thumbnailUrl!,
                              height: 110,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Badge social proof
                    if (product.orderCount != null && product.orderCount! > 10)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${product.orderCount}+ fois',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Badge epuise
                    if (!isAvailable)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: LiliaBadge(
                          label: product.unavailability?.badge ?? 'Indisponible',
                          variant: LiliaBadgeVariant.danger,
                        ),
                      ),
                  ],
                ),
                // Infos du plat
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (product.restaurantName != null)
                          Text(
                            product.restaurantName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                product.priceLabel,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            if (isAvailable)
                              QuickAddButton(product: product, visualSize: 28),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          height: 110,
          width: double.infinity,
          color: cs.surfaceContainerHighest,
          child: Icon(Icons.fastfood, size: 36, color: cs.outline),
        );
      },
    );
  }
}
