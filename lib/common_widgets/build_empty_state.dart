import 'package:flutter/material.dart';

Widget buildEmptyState(BuildContext context) {
  final theme = Theme.of(context);
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.article_outlined,
          size: 32,
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text('Aucune commande trouvée', style: theme.textTheme.bodyMedium),
      ],
    ),
  );
}
