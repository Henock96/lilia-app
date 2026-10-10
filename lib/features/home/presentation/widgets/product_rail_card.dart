import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

/// Largeur d'une carte produit de rail.
const double kProductRailCardWidth = 160;

/// Hauteur d'une carte produit de rail pour la taille de texte courante.
///
/// Elle était fixée à 220 : dès 1.5× le texte ne tenait plus sous l'image, et
/// à 2× le prix et le « + » disparaissaient (P3-02). Image (110) + textes
/// mis à l'échelle + zone de tap du « + » (48). Jamais sous 220, pour ne rien
/// changer au rendu à 1×.
double productRailCardHeight(TextScaler scaler) {
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

/// Carte produit d'un rail horizontal (« Disponible maintenant »).
///
/// Extraite de l'ancienne carte « Plats populaires », **sans** son badge
/// « 🔥 N+ fois » : aucun compteur de ventes n'est plus servi ni affiché.
/// Le « + » passe par `QuickAddButton`, qui refuse toujours un produit
/// indisponible ; le panier et le checkout serveur restent l'autorité.
class ProductRailCard extends ConsumerWidget {
  const ProductRailCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAvailable = product.isOrderable;

    return Semantics(
      button: true,
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
          width: kProductRailCardWidth,
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
                              errorWidget: const _Placeholder(),
                            )
                          : const _Placeholder(),
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
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 110,
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.fastfood, size: 36, color: cs.outline),
    );
  }
}
