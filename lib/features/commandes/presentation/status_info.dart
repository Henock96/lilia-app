import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/models/order.dart';

/// Présentation d'un statut de commande : libellé, explication, icône et
/// **intention** ([tone]) — jamais une couleur.
///
/// La couleur se déduit de [tone] via `liliaBadgeColors`, dont les teintes
/// sont vérifiées ≥ 4.5:1 en clair et en sombre (`contrast_test.dart`). Les
/// deux tables qui existaient avant le 28/09/2026 (liste et détail des
/// commandes) posaient le libellé en `Colors.lightGreen`, `Colors.orange`,
/// `Colors.teal`… : entre 1.9 et 3.2:1 sur fond clair.
class StatusInfo {
  final String label;
  final String description;
  final LiliaBadgeVariant tone;
  final IconData icon;

  const StatusInfo({
    required this.label,
    required this.description,
    required this.tone,
    required this.icon,
  });

  /// (fond, texte) du statut dans le thème courant.
  (Color bg, Color fg) colors(BuildContext context) => liliaBadgeColors(
    tone,
    isDark: Theme.of(context).brightness == Brightness.dark,
  );
}

/// **Le** vocabulaire des statuts de commande côté client — liste et détail.
///
/// Aligné sur l'enum Dart `OrderStatus`, donc sur le compilateur : un statut
/// ajouté côté serveur tombe dans `unknow` (« Inconnu », visible), jamais dans le vide.
StatusInfo orderStatusInfo(OrderStatus status) => switch (status) {
  OrderStatus.enAttente => const StatusInfo(
    label: 'En attente',
    description: 'Votre commande est en attente de confirmation',
    tone: LiliaBadgeVariant.warning,
    icon: Iconsax.timer_1,
  ),
  OrderStatus.payer => const StatusInfo(
    label: 'Payée',
    description: 'Votre paiement a été confirmé',
    tone: LiliaBadgeVariant.info,
    icon: Iconsax.card_tick,
  ),
  OrderStatus.acceptee => const StatusInfo(
    label: 'Acceptée',
    description: 'Le vendeur a accepté votre commande',
    tone: LiliaBadgeVariant.info,
    icon: Iconsax.like_1,
  ),
  OrderStatus.echecLivraison => const StatusInfo(
    label: 'Livraison non aboutie',
    description:
        'Votre commande n’a pas pu être livrée — le support revient vers vous',
    tone: LiliaBadgeVariant.danger,
    icon: Iconsax.warning_2,
  ),
  OrderStatus.enPreparation => const StatusInfo(
    label: 'En préparation',
    description: 'Le restaurant prépare votre commande',
    tone: LiliaBadgeVariant.primary,
    icon: Iconsax.cake,
  ),
  OrderStatus.pret => const StatusInfo(
    label: 'Prête',
    description: 'Votre commande est prête pour la livraison',
    tone: LiliaBadgeVariant.success,
    icon: Iconsax.tick_circle,
  ),
  OrderStatus.enRoute => const StatusInfo(
    label: 'En route',
    description: 'Votre livreur est en chemin vers vous',
    tone: LiliaBadgeVariant.primary,
    icon: Iconsax.truck_fast,
  ),
  OrderStatus.livrer => const StatusInfo(
    label: 'Livrée',
    description: 'Votre commande a été livrée',
    tone: LiliaBadgeVariant.success,
    icon: Iconsax.verify,
  ),
  OrderStatus.annuler => const StatusInfo(
    label: 'Annulée',
    description: 'Cette commande a été annulée',
    tone: LiliaBadgeVariant.danger,
    icon: Iconsax.close_circle,
  ),
  OrderStatus.unknow => const StatusInfo(
    label: 'Inconnu',
    description: 'Statut inconnu',
    tone: LiliaBadgeVariant.neutral,
    icon: Iconsax.info_circle,
  ),
};

/// Pastille de statut — libellé + icône, jamais la couleur seule.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final OrderStatus status;

  /// Liste des commandes : pastille plus petite.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final info = orderStatusInfo(status);
    final (bg, fg) = info.colors(context);
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: compact ? 12 : 14, color: fg),
          SizedBox(width: compact ? 4 : 6),
          Text(
            info.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête d'un retrait au comptoir (F3-07) : « prête pour la livraison » et
/// « livrée » n'ont pas de sens pour une commande qu'on vient chercher.
/// `null` : le libellé général convient.
StatusInfo? pickupStatusInfo(Order order) {
  if (order.isDelivery) return null;
  switch (order.status) {
    case OrderStatus.pret:
      return const StatusInfo(
        label: 'Prête',
        description: 'Votre commande vous attend au restaurant',
        tone: LiliaBadgeVariant.success,
        icon: Iconsax.shop,
      );
    case OrderStatus.livrer:
      return order.deliveryProof == 'PICKUP_VENDOR_DECLARED'
          ? const StatusInfo(
              label: 'Remise',
              description: 'Le restaurant indique vous avoir remis la commande',
              tone: LiliaBadgeVariant.success,
              icon: Iconsax.shop,
            )
          : const StatusInfo(
              label: 'Récupérée',
              description: 'Vous avez récupéré votre commande',
              tone: LiliaBadgeVariant.success,
              icon: Iconsax.verify,
            );
    default:
      return null;
  }
}
