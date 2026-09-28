import 'package:flutter/material.dart';

import 'package:lilia_app/features/cart/presentation/line_options_text.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/checkout_quote.dart';
import 'package:lilia_app/models/promo_validation_result.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';

/// Récapitulatif du checkout : lignes, frais, remises, total.
///
/// **Affichage seul.** Tous les montants arrivent calculés par
/// `CheckoutPage` (via `CheckoutEstimate`) ; ce widget n'en recalcule aucun
/// et ne décide d'aucune règle. Extrait du `State` du checkout (2 300 lignes)
/// pour qu'une retouche visuelle du récapitulatif ne passe plus par le
/// fichier qui porte le tunnel de paiement.
class CheckoutOrderSummary extends StatelessWidget {
  const CheckoutOrderSummary({
    super.key,
    required this.cart,
    required this.isDelivery,
    required this.subTotal,
    required this.deliveryFee,
    required this.originalDeliveryFee,
    required this.deliverySubsidy,
    required this.serviceFee,
    required this.promo,
    required this.loyaltyDiscount,
    required this.total,
    this.vendorOffer,
  });

  final Cart cart;
  final bool isDelivery;
  final double subTotal;
  final double deliveryFee;

  /// Frais avant promo « livraison offerte », pour le prix barré.
  final double originalDeliveryFee;

  /// F3-02 — part des frais offerte par le vendeur, déjà déduite du devis.
  final double deliverySubsidy;
  final double serviceFee;
  final PromoValidationResult? promo;

  /// Remise fidélité **appliquée** ; 0 si le client n'utilise pas ses points.
  final double loyaltyDiscount;
  final double total;

  /// F3-11 — offre boutique du devis serveur, financée par le vendeur.
  final QuotedVendorOffer? vendorOffer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(LiliaSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: LiliaRadius.mdAll,
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          for (final entry in cart.menuGroups.entries)
            _MenuLine(items: entry.value),
          for (final item in cart.individualItems) _ItemLine(item: item),
          const Divider(height: 24),
          _AmountRow(label: 'Sous-total', amount: formatPrice(subTotal)),
          const SizedBox(height: LiliaSpacing.sm),
          _AmountRow(
            label: 'Frais de livraison',
            trailing: _DeliveryFeeLabel(
              isDelivery: isDelivery,
              deliveryFee: deliveryFee,
              originalDeliveryFee: originalDeliveryFee,
              deliverySubsidy: deliverySubsidy,
              freeDeliveryPromo:
                  promo?.discountType == DiscountType.freeDelivery,
            ),
          ),
          const SizedBox(height: LiliaSpacing.sm),
          _AmountRow(label: 'Frais de service', amount: formatPrice(serviceFee)),
          if (promo != null) ...[
            const SizedBox(height: LiliaSpacing.sm),
            _AmountRow(
              label: 'Promo ${promo!.code}',
              icon: Icons.local_offer,
              amount: promo!.discountLabel,
              color: cs.successText,
            ),
          ],
          // F3-11 — distincte du code promo : ce n'est ni la même remise, ni
          // le même payeur.
          if (vendorOffer != null && vendorOffer!.discount > 0) ...[
            const SizedBox(height: LiliaSpacing.sm),
            _AmountRow(
              key: const Key('checkout_vendor_offer'),
              label: vendorOffer!.label,
              icon: Icons.local_offer,
              amount: '- ${formatPrice(vendorOffer!.discount)}',
              color: cs.successText,
            ),
          ],
          if (loyaltyDiscount > 0) ...[
            const SizedBox(height: LiliaSpacing.sm),
            _AmountRow(
              label: 'Points fidélité',
              icon: Icons.stars,
              amount: '- ${formatPrice(loyaltyDiscount)}',
              color: cs.warningText,
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                formatPrice(total),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({required this.items});
  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final menuInfo = items.first.menu;
    final quantite = items.first.quantite;
    const gras = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LiliaSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${quantite}x ${menuInfo?.nom ?? "Menu"}',
                  style: gras,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(formatPrice((menuInfo?.prix ?? 0) * quantite), style: gras),
            ],
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(left: LiliaSpacing.md, top: 2),
              child: Text(
                '- ${item.product.nom}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LiliaSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantite}x ${item.product.nom}',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                LineOptionsText(item.options),
              ],
            ),
          ),
          Text(
            // F3-09 — prix unitaire serveur (variante + options).
            formatPrice(item.quantite * item.unitPrice),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Une ligne « libellé … montant ». [trailing] remplace [amount] quand le
/// montant a une mise en forme propre (frais de livraison barrés).
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    super.key,
    required this.label,
    this.amount,
    this.trailing,
    this.icon,
    this.color,
  });

  final String label;
  final String? amount;
  final Widget? trailing;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final emphasis = color != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: LiliaSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing ??
            Text(
              amount ?? '',
              style: TextStyle(
                fontSize: 15,
                fontWeight: emphasis ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
      ],
    );
  }
}

class _DeliveryFeeLabel extends StatelessWidget {
  const _DeliveryFeeLabel({
    required this.isDelivery,
    required this.deliveryFee,
    required this.originalDeliveryFee,
    required this.deliverySubsidy,
    required this.freeDeliveryPromo,
  });

  final bool isDelivery;
  final double deliveryFee;
  final double originalDeliveryFee;
  final double deliverySubsidy;
  final bool freeDeliveryPromo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final offert = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: cs.successText,
    );

    Widget barre(double montant, String apres) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatPrice(montant),
          style: TextStyle(
            fontSize: 14,
            decoration: TextDecoration.lineThrough,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Text(apres, style: offert),
      ],
    );

    if (!isDelivery) return Text('Gratuit', style: offert);
    if (freeDeliveryPromo) return barre(originalDeliveryFee, 'Gratuit');
    // F3-02 — part offerte par le vendeur : le devis l'a déjà déduite, on
    // montre seulement le prix de base barré.
    if (deliverySubsidy > 0) {
      return barre(
        deliveryFee + deliverySubsidy,
        deliveryFee == 0 ? 'Offerte' : formatPrice(deliveryFee),
      );
    }
    return Text(
      formatPrice(deliveryFee),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
  }
}
