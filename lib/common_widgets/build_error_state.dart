import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BuildErrorState extends ConsumerStatefulWidget {
  const BuildErrorState(this.error, {super.key});
  final Object error;
  @override
  ConsumerState createState() => _BuildErrorStateState();
}

class _BuildErrorStateState extends ConsumerState<BuildErrorState> {
  @override
  Widget build(BuildContext context) {
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
              setState(() {

              });
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );

  }
}
