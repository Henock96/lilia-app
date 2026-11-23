import 'package:flutter/material.dart';

import 'package:lilia_app/features/commandes/domain/order_timeline.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Frise horizontale d'une commande — livraison ou retrait (P3-09).
///
/// Revenue à l'horizontale le 22/11/2026, à la demande du produit : la frise
/// en ligne se lit d'un coup d'œil. Les étapes restent celles de
/// `orderTimeline` (justes, par mode et par parcours) ; seuls leurs libellés
/// **courts** tiennent côte à côte sur 360 dp, le libellé complet restant
/// celui que le lecteur d'écran annonce. La précision de l'étape en cours
/// (« En attente du livreur ») s'affiche sous la frise, en toutes lettres.
class OrderTimelineView extends StatelessWidget {
  const OrderTimelineView({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final steps = orderTimeline(order);
    if (steps.isEmpty) return const SizedBox.shrink();
    final current = steps
        .where((s) => s.state == TimelineStepState.current)
        .firstOrNull;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: _StepCell(
                  step: steps[i],
                  isFirst: i == 0,
                  isLast: i == steps.length - 1,
                  // Le trait qui mène à cette étape est vert dès qu'on y est.
                  incomingReached:
                      steps[i].state != TimelineStepState.upcoming,
                ),
              ),
          ],
        ),
        if (current?.detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              current!.detail!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _StepCell extends StatelessWidget {
  const _StepCell({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.incomingReached,
  });

  final TimelineStep step;
  final bool isFirst;
  final bool isLast;
  final bool incomingReached;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = step.state == TimelineStepState.done;
    final current = step.state == TimelineStepState.current;
    final reached = done || current;
    // Texte : `successText` / `onSurfaceVariant` (≥ 4,5:1), jamais
    // `outline` (1,26:1).
    final color = reached ? cs.successText : cs.onSurfaceVariant;
    final faded = cs.onSurfaceVariant.withValues(alpha: 0.35);
    final etat = current
        ? 'en cours'
        : done
        ? 'terminée'
        : 'à venir';
    final size = current ? 30.0 : 24.0;

    Widget connector(bool visible, bool green) => Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: !visible ? Colors.transparent : (green ? cs.successText : faded),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

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
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: Row(
              children: [
                connector(!isFirst, incomingReached),
                Container(
                  width: size,
                  height: size,
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
                connector(!isLast, done),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Texte agrandi (1.5×) sur un petit écran : le libellé rétrécit
          // dans sa cellule au lieu d'être coupé en plein mot. La précision
          // de l'étape en cours, sous la frise, garde la taille choisie.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              step.shortLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: current ? FontWeight.bold : FontWeight.w500,
                color: current ? cs.onSurface : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
