import 'package:firebase_auth/firebase_auth.dart';
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';

import '../../../../models/produit.dart';
import '../../../../routing/app_route_enum.dart';
import '../../data/remote/home_controller.dart';
import 'section_header.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';

class RecommendationsSection extends ConsumerWidget {
  const RecommendationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ne montrer que si l'utilisateur est connecte
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final recommendationsAsync = ref.watch(recommendationsProvider);

    return recommendationsAsync.when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const SectionHeader(title: 'Recommande pour vous'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _RecommendationCard(
                    product: products[index],
                  ).fadeScaleIn(delay: AppMotion.stagger * index.clamp(0, 5));
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RecommendationCard extends ConsumerWidget {
  final Product product;

  const _RecommendationCard({required this.product});

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
        // émet `product_view`.
        onTap: () => context.pushNamed(
          AppRoutes.productDetail.routeName,
          pathParameters: {'productId': product.id},
          extra: product,
        ),
        child: Container(
          width: 160,
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
            opacity: isAvailable ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
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
                              errorWidget: _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Badge recommande
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.thumb_up, color: Colors.white, size: 10),
                            SizedBox(width: 3),
                            Text(
                              'Pour vous',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                // Infos
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (product.restaurantName != null)
                          Text(
                            product.restaurantName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
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
                                  color: theme.primaryColor,
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
    return Container(
      height: 110,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.fastfood, size: 36, color: Colors.grey),
      ),
    );
  }
}
