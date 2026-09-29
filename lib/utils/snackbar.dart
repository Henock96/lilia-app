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
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    // Fonds ≥ 4,5:1 sous du texte blanc : `green500` (4,39:1) et `red400`
    // passaient sous le seuil AA (P3-19). Voir `snackBarBackground`.
    final bg = snackBarBackground(type);
    final icon = switch (type) {
      SnackType.success => Icons.check_circle_rounded,
      SnackType.error => Icons.error_rounded,
      SnackType.info => Icons.info_rounded,
    };

    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          // Jamais moins que le temps de lecture du message (P3-19) : 2 s
          // pour un message de trois lignes, c'était un message perdu.
          duration: snackBarDuration(message, minimum: duration),
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
    duration: duration ?? const Duration(seconds: 2),
  );

  void showErrorSnack(String message, {Duration? duration}) => showSnack(
    message,
    type: SnackType.error,
    duration: duration ?? const Duration(seconds: 3),
  );
}

/// Fond d'un snackbar selon son type — exposé pour `contrast_test`.
Color snackBarBackground(SnackType type) => switch (type) {
  SnackType.success => LiliaColors.green700,
  SnackType.error => LiliaColors.red500,
  SnackType.info => LiliaColors.charcoal700,
};

/// Durée d'affichage : au moins [minimum], et assez pour lire [message]
/// (~15 caractères par seconde, plus une seconde), plafonnée à 10 s.
Duration snackBarDuration(String message, {required Duration minimum}) {
  final lecture = Duration(milliseconds: 1000 + message.length * 66);
  final d = lecture > minimum ? lecture : minimum;
  const plafond = Duration(seconds: 10);
  return d > plafond ? plafond : d;
}
