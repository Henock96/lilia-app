import 'package:flutter/material.dart';

import 'shimmer_box.dart';

/// Squelette d'un rail horizontal, à la **hauteur exacte** de la section
/// réelle : l'arrivée des données ne fait rien sauter.
class RailSkeleton extends StatelessWidget {
  const RailSkeleton({
    super.key,
    required this.height,
    required this.cardWidth,
    this.cards = 3,
  });

  final double height;
  final double cardWidth;
  final int cards;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: cards,
          itemBuilder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ShimmerBox(
              width: cardWidth,
              height: height,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
