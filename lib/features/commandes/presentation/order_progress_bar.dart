import 'package:flutter/material.dart';

import 'package:lilia_app/features/commandes/domain/order_timeline.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Progression compacte d'une commande dans la **liste** des commandes.
///
/// Même règle que la timeline du détail ([orderTimeline]) : elle recopiait
/// l'ancien stepper à 4 étapes — « Confirmée » pour une commande qui attend
/// son paiement, « En route » pour un retrait, aucune étape en cours pour
/// `PAYER` / `ACCEPTEE` (P3-09). Une ligne de texte plutôt que quatre
/// libellés de 9 px : lisible, et elle tient avec le texte agrandi.
class OrderProgressBar extends StatelessWidget {
  const OrderProgressBar({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final steps = orderTimeline(order);
    if (steps.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final index = steps.indexWhere((s) => s.state == TimelineStepState.current);
    final current = index < 0 ? null : steps[index];
    final label = current == null
        ? steps.last.label
        : [current.label, ?current.detail].join(' · ');

    return Semantics(
      label:
          'Étape ${index < 0 ? steps.length : index + 1} sur '
          '${steps.length} : $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border(
            top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: steps[i].state == TimelineStepState.upcoming
                            ? cs.onSurfaceVariant.withValues(alpha: 0.25)
                            : cs.successText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
