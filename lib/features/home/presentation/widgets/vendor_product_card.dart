import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Carte produit de la fiche vendeur — extraite de
/// `restaurant_detail_screen.dart`.
///
/// Changements par rapport à la version embarquée :
///
/// - image par `AppCachedImage` et non `NetworkImage` : la carte du vendeur,
///   écran le plus parcouru du catalogue, était la seule à contourner le cache
///   disque (`LiliaImageCache`) — chaque visite retéléchargeait les vignettes ;
/// - pastilles `LiliaBadge` (libellé + icône, contraste vérifié) au lieu de
///   blanc sur `Colors.orange` (≈ 2.2:1 en 10 px) ;
/// - indisponible : seule l'image est estompée. L'`Opacity(0.5)` sur toute la
///   carte divisait aussi le contraste du nom et du motif d'indisponibilité ;
/// - le tap et sa sémantique de bouton appartiennent à la carte.
class VendorProductCard extends StatelessWidget {
  const VendorProductCard({super.key, required this.product});

  final Product product;

  static const double _imageSize = 85;

  @override
  Widget build(BuildContext context) {
    // `isOrderable` = en vente ET en stock. Le getter `isAvailable` d'avant
    // ne regardait que le stock et masquait le champ du serveur (fix S-3).
    final available = product.isOrderable;
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      // Sans ce label, un lecteur d'écran présente un produit indisponible
      // comme disponible : l'état n'était porté que par l'apparence.
      label: available
          ? '${product.name}, ${product.priceLabel}'
          : '${product.name}, ${product.unavailability?.badge ?? 'épuisé'}',
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: LiliaSpacing.sm),
        shape: const RoundedRectangleBorder(borderRadius: LiliaRadius.mdAll),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pushNamed(
            AppRoutes.productDetail.routeName,
            pathParameters: {'productId': product.id},
            extra: product,
          ),
          child: Padding(
            padding: const EdgeInsets.all(LiliaSpacing.sp3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: available ? 1 : 0.5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    child: product.imageUrl != null
                        ? AppCachedImage(
                            imageUrl: product.imageUrl!,
                            width: _imageSize,
                            height: _imageSize,
                            fit: BoxFit.cover,
                            errorIcon: Icons.fastfood,
                          )
                        : Container(
                            width: _imageSize,
                            height: _imageSize,
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.fastfood,
                              size: 40,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: LiliaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: LiliaSpacing.xs),
                        Text(
                          product.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_badge != null) ...[
                        const SizedBox(height: LiliaSpacing.xs),
                        _badge!,
                      ],
                      const SizedBox(height: LiliaSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              // « À partir de X » dès qu'il y a plusieurs
                              // formats : annoncer le prix de l'un sans dire
                              // lequel est une promesse qu'on ne tient pas au
                              // panier. Même règle que le web.
                              product.priceLabel,
                              style: TextStyle(
                                color: available
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (available)
                            QuickAddButton(
                              product: product,
                              visualSize: 36,
                              multipleVariantsOpenProduct: true,
                            ),
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

  /// Une seule pastille, par ordre d'importance.
  ///
  /// « Épuisé », « Indisponible » et « Hors créneau » sont trois informations
  /// différentes : une rupture du jour, une décision du vendeur, un horaire.
  /// Les confondre dit au client d'attendre demain quand il devrait revenir
  /// à 6 h.
  Widget? get _badge {
    if (!product.isOrderable) {
      return LiliaBadge(
        label: product.unavailability?.badge ?? 'Épuisé',
        variant: LiliaBadgeVariant.danger,
        icon: Icons.block_rounded,
      );
    }
    if (product.madeToOrder) {
      return const LiliaBadge(
        label: 'Sur commande',
        variant: LiliaBadgeVariant.info,
        icon: Icons.schedule_rounded,
      );
    }
    if (product.variants.length > 1) {
      return LiliaBadge(
        label: '${product.variants.length} formats',
        variant: LiliaBadgeVariant.primary,
        icon: Icons.tune_rounded,
      );
    }
    return null;
  }
}
