import 'package:flutter/material.dart';

import 'package:lilia_app/models/service_modes.dart';

/// Modes de service d'un vendeur, tels que le client peut les choisir :
/// « Livraison », « Retrait sur place ». Seuls les modes proposés sont
/// affichés ; rien si aucun.
class ServiceModeBadges extends StatelessWidget {
  const ServiceModeBadges({super.key, required this.modes});

  final ServiceModes modes;

  @override
  Widget build(BuildContext context) {
    if (modes.none) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (modes.delivery)
          const _ModeLabel(
            icon: Icons.delivery_dining_outlined,
            text: 'Livraison',
          ),
        if (modes.pickup)
          const _ModeLabel(
            icon: Icons.storefront_outlined,
            text: 'Retrait sur place',
          ),
      ],
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
