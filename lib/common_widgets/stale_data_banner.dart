import 'package:flutter/material.dart';

import 'package:lilia_app/theme/lilia_tokens.dart';

/// « Hors ligne — données de 14:05 » au-dessus d'une liste conservée (P3-12).
///
/// Une liste gardée après un échec de rechargement n'est **pas** à jour : on
/// le dit, avec l'heure du dernier chargement réussi, et on rappelle que la
/// disponibilité et les prix sont vérifiés à la commande. Jamais d'ajout
/// « garanti » parce qu'une carte apparaît dans un cache.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    super.key,
    required this.loadedAt,
    this.onRetry,
    this.title,
  });

  final DateTime loadedAt;
  final VoidCallback? onRetry;

  /// Titre à la place de « Hors ligne — liste chargée à … » (l'heure y est
  /// alors ajoutée) : « Disponibilités à vérifier (hors ligne) ».
  final String? title;

  static String hhmm(DateTime at) {
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 20, color: cs.warningText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title == null
                        ? 'Hors ligne — liste chargée à ${hhmm(loadedAt)}'
                        : '$title — ${hhmm(loadedAt)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Ouvertures et prix sont vérifiés à la commande.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
