import 'package:flutter/material.dart';

import 'package:lilia_app/features/commandes/domain/order_timeline.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Timeline verticale d'une commande — livraison ou retrait (P3-09).
///
/// Verticale et non plus en ligne : six libellés côte à côte ne tiennent pas
/// sur un téléphone de 360 dp, encore moins avec le texte agrandi.
class OrderTimelineView extends StatelessWidget {
  const OrderTimelineView({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final steps = orderTimeline(order);
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = step.state == TimelineStepState.done;
    final current = step.state == TimelineStepState.current;
    final reached = done || current;
    // Texte : `successText` / `onSurfaceVariant` (≥ 4,5:1), jamais
    // `outline` (1,26:1).
    final color = reached ? cs.successText : cs.onSurfaceVariant;
    final etat = current
        ? 'en cours'
        : done
        ? 'terminée'
        : 'à venir';

    // L'étape en cours est une *live region* : quand le statut change sous
    // les yeux du client (FCM, relecture), le lecteur d'écran l'annonce.
    return Semantics(
      liveRegion: current,
      label: [
        step.label,
        etat,
        if (step.detail != null) step.detail!,
      ].join(', '),
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? cs.successText : cs.surface,
                      border: Border.all(
                        color: reached ? cs.successText : cs.onSurfaceVariant,
                        width: current ? 3 : 1.5,
                      ),
                    ),
                    child: done
                        ? Icon(Icons.check, size: 14, color: cs.surface)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: done
                            ? cs.successText
                            : cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: current ? FontWeight.bold : FontWeight.w500,
                        color: current ? cs.onSurface : color,
                      ),
                    ),
                    if (step.detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          step.detail!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
