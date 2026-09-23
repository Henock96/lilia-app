import 'package:flutter/material.dart';

/// Code de remise à montrer au livreur (Master Audit v1, F-06).
///
/// Le livreur ne peut déclarer la commande livrée qu'en saisissant ce code :
/// c'est la preuve que le client a bien reçu son repas. Il n'est affiché qu'au
/// client, et seulement pendant que la commande roule vers lui.
class HandoverCodeCard extends StatelessWidget {
  const HandoverCodeCard({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Code de remise',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Code de remise ${code.split('').join(' ')}',
            excludeSemantics: true,
            child: Text(
              code,
              key: const Key('handover-code'),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Donnez ce code au livreur quand il vous remet la commande — '
            'jamais avant. Sans lui, il ne peut pas la déclarer livrée.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
