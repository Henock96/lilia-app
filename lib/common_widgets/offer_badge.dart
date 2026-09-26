import 'package:flutter/material.dart';

import 'package:lilia_app/models/active_offer.dart';

/// Badge « −10 % » d'une offre boutique (F3-11), posé sur la carte ou
/// l'en-tête d'un vendeur. [expanded] affiche le libellé complet du serveur
/// (« −10 % sur toute la boutique ») au lieu du seul montant.
class OfferBadge extends StatelessWidget {
  const OfferBadge({super.key, required this.offer, this.expanded = false});

  final ActiveOffer offer;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final text = expanded && offer.label.isNotEmpty ? offer.label : offer.badge;
    return Semantics(
      label: 'Offre : ${offer.label.isNotEmpty ? offer.label : offer.badge}',
      child: Container(
        key: const Key('offer-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFD84315),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
