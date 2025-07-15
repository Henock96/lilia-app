import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BuildErrorState extends ConsumerWidget {
  const BuildErrorState(this.error, {super.key, });
  final Object error;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: theme.colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Erreur de chargement',
            style: theme.textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: () {
              /*ref.refresh(newsArticlesProvider(
                NewsQueryParams(
                  country: country,
                  categories: preferredCategories,
                ),
              ));*/
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
