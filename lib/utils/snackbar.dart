import 'package:flutter/material.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Type sémantique d'un snackbar — pilote couleur + icône.
enum SnackType { success, error, info }

/// Helpers centralisés pour les `SnackBar` de l'app (remplace les ~23 appels
/// inline `ScaffoldMessenger.of(context).showSnackBar(...)`).
///
/// Style premium et cohérent : flottant, coins arrondis, icône sémantique,
/// marge confortable. Usage :
/// ```dart
/// context.showSuccessSnack('Ajouté au panier');
/// context.showErrorSnack(message);
/// ```
extension SnackBarX on BuildContext {
  void showSnack(
    String message, {
    SnackType type = SnackType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final (Color bg, IconData icon) = switch (type) {
      SnackType.success => (LiliaColors.green500, Icons.check_circle_rounded),
      SnackType.error => (LiliaColors.red400, Icons.error_rounded),
      SnackType.info => (LiliaColors.charcoal700, Icons.info_rounded),
    };

    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          duration: duration,
          elevation: 4,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          action: action,
        ),
      );
  }

  void showSuccessSnack(String message, {Duration? duration}) => showSnack(
        message,
        type: SnackType.success,
        duration: duration ?? const Duration(seconds: 3),
      );

  void showErrorSnack(String message, {Duration? duration}) => showSnack(
        message,
        type: SnackType.error,
        duration: duration ?? const Duration(seconds: 4),
      );
}
