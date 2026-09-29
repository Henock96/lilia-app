import 'package:flutter/material.dart';
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/models/produit.dart';

/// Pastille de disponibilité d'un produit, lue **uniquement** dans
/// [Product.unavailability] — la règle commune à toutes les cartes.
///
/// « Disponible » n'est affiché que si le produit est commandable d'après ce
/// que la réponse du serveur dit : boutique non fermée, en vente, en stock, dans
/// son créneau. Le serveur reste l'arbitre final au panier et au checkout.
class ProductAvailabilityBadge extends StatelessWidget {
  const ProductAvailabilityBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final reason = product.unavailability;
    if (reason == null) {
      return const LiliaBadge(
        label: 'Disponible',
        variant: LiliaBadgeVariant.success,
        icon: Icons.check_circle_rounded,
      );
    }
    return LiliaBadge(
      label: reason == ProductUnavailability.boutiqueFermee
          ? 'Boutique fermée'
          : reason.badge,
      variant: LiliaBadgeVariant.danger,
      icon: reason == ProductUnavailability.boutiqueFermee
          ? Icons.storefront_rounded
          : Icons.block_rounded,
    );
  }
}
