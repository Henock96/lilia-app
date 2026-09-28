import 'package:flutter/material.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';

/// Libellé et intention du verdict de stock **publié par le serveur**
/// (`stockStatus`, seuil LOW compris). Le client ne recalcule rien.
///
/// `null` quand l'endpoint ne publie pas de verdict (recherche, populaires,
/// recommandations) : on n'affiche rien plutôt qu'un « Stock à vérifier »
/// anxiogène sur chaque ligne — le panier et le checkout arbitrent.
/// `UNLIMITED` et `AVAILABLE` ne s'affichent pas non plus : « disponible »
/// est l'état normal d'un catalogue, le signaler partout noierait les deux
/// seuls messages utiles (bientôt épuisé, épuisé).
({String label, LiliaBadgeVariant variant, IconData icon})? stockVerdictBadge(
  ProductVariant variant,
) {
  if (!variant.isInStock) {
    return (
      label: 'Épuisé',
      variant: LiliaBadgeVariant.danger,
      icon: Icons.block_rounded,
    );
  }
  if (variant.stockStatus?.toUpperCase() == 'LOW') {
    final q = variant.availableQuantity;
    return (
      label: q == null
          ? 'Stock faible'
          : 'Plus que $q disponible${q == 1 ? '' : 's'}',
      variant: LiliaBadgeVariant.warning,
      icon: Icons.hourglass_bottom_rounded,
    );
  }
  return null;
}

/// Badge de stock d'un format. Rien si le verdict ne mérite pas d'être dit.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.variant});
  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    final badge = stockVerdictBadge(variant);
    if (badge == null) return const SizedBox.shrink();
    return LiliaBadge(
      label: badge.label,
      variant: badge.variant,
      icon: badge.icon,
    );
  }
}

/// Sélection partagée des formats depuis les ajouts rapides
/// (`quickAddProduct`). Renvoie `null` si le client ferme la feuille ; un
/// format épuisé n'est jamais sélectionnable.
Future<ProductVariant?> showVariantSelectionSheet(
  BuildContext context,
  Product product,
) => showModalBottomSheet<ProductVariant>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) {
    final textTheme = Theme.of(sheetContext).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        LiliaSpacing.screenH,
        0,
        LiliaSpacing.screenH,
        LiliaSpacing.md + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(product.name, style: textTheme.titleLarge),
          ),
          if (product.restaurantName != null)
            Text(product.restaurantName!, style: textTheme.bodySmall),
          const SizedBox(height: LiliaSpacing.md),
          Text('Choisissez un format', style: textTheme.titleSmall),
          const SizedBox(height: LiliaSpacing.sm),
          VariantSelector(
            variants: product.variants,
            selected: null,
            onSelected: (variant) => Navigator.of(sheetContext).pop(variant),
          ),
        ],
      ),
    );
  },
);

/// Liste radio des formats : libellé, unité contenue, verdict de stock, prix.
class VariantSelector extends StatelessWidget {
  const VariantSelector({
    super.key,
    required this.variants,
    required this.selected,
    required this.onSelected,
  });
  final List<ProductVariant> variants;
  final ProductVariant? selected;
  final ValueChanged<ProductVariant> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final variant in variants)
        Padding(
          padding: const EdgeInsets.only(bottom: LiliaSpacing.sm),
          child: _VariantTile(
            variant: variant,
            isSelected: selected?.id == variant.id,
            onTap: variant.isInStock ? () => onSelected(variant) : null,
          ),
        ),
    ],
  );
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.isSelected,
    required this.onTap,
  });

  final ProductVariant variant;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final badge = stockVerdictBadge(variant);
    // Un format épuisé est grisé par ses couleurs, pas par une `Opacity` : la
    // transparence faisait aussi tomber le contraste du mot « Épuisé ».
    final labelColor = enabled ? cs.onSurface : cs.onSurfaceVariant;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      enabled: enabled,
      label: [
        variant.displayLabel,
        formatPrice(variant.prix),
        if (variant.stockConsumption > 1)
          'contient ${variant.stockConsumption} unités',
        if (badge != null) badge.label,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: isSelected
            ? cs.primary.withValues(alpha: .07)
            : cs.surfaceContainerHighest.withValues(alpha: .45),
        shape: RoundedRectangleBorder(
          borderRadius: LiliaRadius.mdAll,
          side: BorderSide(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LiliaSpacing.sp3,
                vertical: LiliaSpacing.sp3,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: LiliaSpacing.sp3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant.displayLabel,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                        if (variant.stockConsumption > 1)
                          Text(
                            'Contient ${variant.stockConsumption} unités',
                            style: textTheme.bodySmall,
                          ),
                        if (badge != null) ...[
                          const SizedBox(height: LiliaSpacing.xs),
                          LiliaBadge(
                            label: badge.label,
                            variant: badge.variant,
                            icon: badge.icon,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: LiliaSpacing.sm),
                  Text(
                    formatPrice(variant.prix),
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      decoration: enabled ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
