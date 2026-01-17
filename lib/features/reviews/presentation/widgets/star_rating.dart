import 'package:flutter/material.dart';

/// Widget pour afficher les étoiles (lecture seule)
class StarRating extends StatelessWidget {
  final double rating;
  final int totalStars;
  final double size;
  final Color? color;
  final bool showValue;

  const StarRating({
    super.key,
    required this.rating,
    this.totalStars = 5,
    this.size = 18,
    this.color,
    this.showValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Colors.amber;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(totalStars, (index) {
          double fillAmount = (rating - index).clamp(0.0, 1.0);

          return Icon(
            fillAmount >= 1
                ? Icons.star
                : fillAmount > 0
                    ? Icons.star_half
                    : Icons.star_border,
            size: size,
            color: starColor,
          );
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget pour sélectionner une note (interactif)
class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final int totalStars;
  final double size;
  final Color? color;

  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.totalStars = 5,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Colors.amber;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalStars, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => onRatingChanged(starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              starIndex <= rating ? Icons.star : Icons.star_border,
              size: size,
              color: starColor,
            ),
          ),
        );
      }),
    );
  }
}

/// Widget compact pour afficher note + nombre d'avis
class RatingBadge extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double iconSize;

  const RatingBadge({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return Text(
        'Pas encore d\'avis',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: iconSize,
          color: Colors.amber,
        ),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: iconSize * 0.9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviewCount)',
          style: TextStyle(
            fontSize: iconSize * 0.75,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
