import 'package:flutter/material.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';

/// Pastilles de pagination : l'active est allongée, dans la couleur d'action.
///
/// Annoncées comme un seul élément (« Page 2 sur 3 ») : trois pastilles lues
/// une à une n'apprendraient rien au lecteur d'écran.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  static const double activeWidth = 24;
  static const double size = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      label: 'Page ${index + 1} sur $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppMotion.fast,
              curve: AppMotion.curve,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? activeWidth : size,
              height: size,
              decoration: BoxDecoration(
                color: i == index ? scheme.primary : scheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(size / 2),
              ),
            ),
        ],
      ),
    );
  }
}
