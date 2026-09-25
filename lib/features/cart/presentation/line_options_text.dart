import 'package:flutter/material.dart';

import 'package:lilia_app/models/modifier.dart';
import 'package:lilia_app/utils/currency.dart';

/// F3-09 — les options d'une ligne (panier ou commande), sous le nom du plat :
///
/// ```
/// Poulet braisé
/// Alloco · Œuf ×2 (+600)
/// ```
///
/// Le supplément affiché est celui de la ligne pour une unité ; il est déjà
/// compris dans le prix de la ligne — on l'affiche, on ne l'ajoute pas.
class LineOptionsText extends StatelessWidget {
  const LineOptionsText(this.options, {super.key, this.style});

  final List<LineOption> options;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = options
        .map((o) {
          final delta = o.priceDeltaXaf * o.quantity;
          return delta > 0 ? '${o.label} (+${formatAmount(delta)})' : o.label;
        })
        .join(' · ');
    return Text(
      text,
      key: const ValueKey('line-options'),
      style: style ?? TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
    );
  }
}
