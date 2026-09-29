import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lilia_app/features/cart/domain/cart_price_preview.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/quartiers/domain/delivery_fee_label.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/utils/currency.dart';

/// Récapitulatif du prix au pied du panier (P3-11).
///
/// Chaque ligne dit d'où vient le montant ; rien n'est présenté comme final.
/// Voir [CartPricePreview] pour ce qui est calculé et ce qui ne l'est pas.
class CartPriceSummary extends ConsumerWidget {
  const CartPriceSummary({super.key, required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(platformSettingsProvider);
    final settings = settingsAsync.value;
    final preview = CartPricePreview.compute(
      subTotal: cart.totalPrice,
      settings: settings,
    );

    final restaurantId = cart.items.isEmpty
        ? null
        : cart.items.first.product.restaurantId;
    final vendor = restaurantId == null
        ? null
        : ref.watch(restaurantControllerProvider(restaurantId)).value;

    final deliveryValue = vendor == null
        ? 'À l\'étape suivante'
        : deliveryFeeLabel(vendor.fixedDeliveryFee, settings);

    final muted = TextStyle(fontSize: 13, color: cs.onSurfaceVariant);
    final articles = cart.totalItems;

    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Line(
            label: 'Sous-total ($articles article${articles > 1 ? 's' : ''})',
            value: formatPrice(preview.subTotal),
            style: muted,
          ),
          _Line(
            label: preview.serviceFeePercentLabel == null
                ? 'Frais de service'
                : 'Frais de service (${preview.serviceFeePercentLabel})',
            value: preview.serviceFee != null
                ? formatPrice(preview.serviceFee!)
                // `hasError` avant `isLoading` : Riverpod 3 relance tout
                // seul un échec, et la relance garde l'erreur. Tester
                // `isLoading` d'abord laisserait « … » à l'infini.
                : settingsAsync.hasError || !settingsAsync.isLoading
                ? 'Calculés à l\'étape suivante'
                : '…',
            style: muted,
          ),
          _Line(
            label: 'Livraison',
            value: deliveryValue,
            style: muted,
            hint: 'selon l\'adresse · gratuite en retrait',
          ),
          const SizedBox(height: 6),
          if (preview.estimatedTotalBeforeDelivery != null)
            _Line(
              label: 'Total estimé hors livraison',
              value: formatPrice(preview.estimatedTotalBeforeDelivery!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            )
          else
            _Line(
              label: 'Sous-total',
              value: formatPrice(preview.subTotal),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          Text(
            'Offres, codes promo et points s\'appliquent à l\'étape suivante. '
            'Le montant final vous est confirmé avant le paiement.',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Une ligne libellé / montant qui passe à la ligne au lieu de déborder quand
/// le texte est agrandi.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.style,
    this.hint,
  });

  final String label;
  final String value;
  final TextStyle style;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: style),
              if (hint != null)
                Text(
                  hint!,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
            ],
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
