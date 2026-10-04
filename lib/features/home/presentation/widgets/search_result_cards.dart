import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';
import 'package:lilia_app/features/home/domain/opening_label.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Côté de la vignette d'un résultat de recherche (56 auparavant).
const double kSearchThumbSize = 84;

/// Titre de section de la recherche, avec un sous-titre facultatif.
class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: LiliaSpacing.md,
        bottom: LiliaSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Carte « boutique » d'un résultat de recherche.
///
/// Tout ce qu'elle affiche vient du serveur : ouverture (`isOpen`, et la date
/// de réouverture quand elle est servie), délai annoncé par le vendeur,
/// spécialités. Aucune note ni distance : la recherche ne les sert pas, et on
/// ne les invente pas.
class SearchVendorCard extends StatelessWidget {
  const SearchVendorCard({super.key, required this.vendor, this.onOpen});

  final RestaurantSummary vendor;

  /// Appelé avant la navigation (mémorisation de la recherche).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isOpen = vendor.isOpen == true;
    final opening = openingLabel(
      vendor.isOpen,
      vendor.pausedUntil,
      nextOpeningAt: vendor.nextOpeningAt,
      nextOpeningServed: vendor.nextOpeningServed,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: LiliaSpacing.sm),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          onOpen?.call();
          // `push` et non `go` : `go` remplaçait l'écran de recherche, et le
          // retour ramenait à l'accueil en perdant la requête.
          context.pushNamed(
            AppRoutes.restaurantDetail.routeName,
            pathParameters: {'id': vendor.id},
            extra: {'restaurantName': vendor.name},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(LiliaSpacing.sp3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(
                url: vendor.thumbnailUrl,
                icon: Icons.storefront_outlined,
                dimmed: !isOpen,
              ),
              const SizedBox(width: LiliaSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${vendor.vendorType.emoji} ${vendor.vendorType.label}',
                        if (vendor.specialties.isNotEmpty)
                          vendor.specialtiesFormatted,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: LiliaSpacing.sm),
                    Wrap(
                      spacing: LiliaSpacing.sm,
                      runSpacing: LiliaSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LiliaBadge(
                          label: opening,
                          variant: isOpen
                              ? LiliaBadgeVariant.success
                              : LiliaBadgeVariant.neutral,
                          dot: true,
                        ),
                        if (isOpen)
                          _Meta(
                            icon: Icons.schedule,
                            text: vendor.deliveryTimeFormatted,
                          ),
                        if (!isOpen && vendor.acceptsPreorders)
                          const _Meta(
                            icon: Icons.event_available_outlined,
                            text: 'Précommande possible',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte « produit » d'un résultat de recherche.
///
/// Commandable : prix, formats, « Plus que N » (verdict serveur), et le « + »
/// d'ajout rapide. Non commandable : la raison (« Fermé », « Épuisé »,
/// « Hors créneau »…), **aucun** bouton d'ajout — la fiche reste consultable.
class SearchProductCard extends StatelessWidget {
  const SearchProductCard({super.key, required this.product, this.onOpen});

  final Product product;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reason = product.unavailability;
    final orderable = reason == null;
    final lowQuantity = product.variants
        .map((v) => v.lowQuantity)
        .whereType<int>()
        .fold<int?>(null, (m, q) => m == null || q > m ? q : m);
    final description = product.description.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: LiliaSpacing.sm),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          onOpen?.call();
          context.pushNamed(
            AppRoutes.productDetail.routeName,
            pathParameters: {'productId': product.id},
            extra: product,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(LiliaSpacing.sp3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(
                url: product.thumbnailUrl,
                icon: Icons.restaurant_menu,
                dimmed: !orderable,
              ),
              const SizedBox(width: LiliaSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.restaurantName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: LiliaSpacing.xs),
                          Flexible(
                            child: Text(
                              product.restaurantName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: LiliaSpacing.xs),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: LiliaSpacing.sm),
                    Wrap(
                      spacing: LiliaSpacing.sm,
                      runSpacing: LiliaSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          product.priceLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: orderable ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                        if (product.variants.length > 1)
                          _Meta(
                            icon: Icons.tune,
                            text: '${product.variants.length} formats',
                          ),
                        // Précommande : commandable, mais pas pour tout de
                        // suite — le dire avant la fiche (champ serveur).
                        if (product.madeToOrder && reason == null)
                          const LiliaBadge(
                            label: 'Sur commande',
                            variant: LiliaBadgeVariant.info,
                          ),
                        if (reason != null)
                          LiliaBadge(
                            label: reason.badge,
                            variant:
                                reason == ProductUnavailability.boutiqueFermee
                                ? LiliaBadgeVariant.neutral
                                : LiliaBadgeVariant.danger,
                          )
                        else if (lowQuantity != null)
                          LiliaBadge(
                            label: 'Plus que $lowQuantity',
                            variant: LiliaBadgeVariant.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (orderable)
                Padding(
                  padding: const EdgeInsets.only(left: LiliaSpacing.xs),
                  child: QuickAddButton(product: product),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.icon, this.dimmed = false});

  final String? url;
  final IconData icon;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: kSearchThumbSize,
      height: kSearchThumbSize,
      color: cs.surfaceContainerHighest,
      child: Icon(icon, size: 30, color: cs.onSurfaceVariant),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url != null
          ? AppCachedImage.framed(
              imageUrl: url!,
              width: kSearchThumbSize,
              height: kSearchThumbSize,
              errorWidget: placeholder,
            )
          : placeholder,
    );
    // Atténuée, jamais masquée : l'état est dit par le badge, l'image ne fait
    // que le rappeler.
    return dimmed ? Opacity(opacity: 0.55, child: image) : image;
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
