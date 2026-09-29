import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/core/log.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';

class BuildErrorState extends ConsumerWidget {
  const BuildErrorState(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        // Annoncé par TalkBack / VoiceOver quand il remplace un chargement :
        // sans cela, l'échec n'est perçu que par qui regarde l'écran.
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatError(error),
                // `onSurfaceVariant` et non `Colors.grey[600]` : le gris fixe
                // tombait sous le seuil de contraste sur le fond sombre.
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatError(Object error) => userFacingErrorMessage(error);
}

/// Message affichable d'une erreur de chargement.
///
/// `ApiException` porte déjà un message français destiné au client (voir
/// `ApiClient`). Tout le reste — `TypeError` d'un parsing, `SocketException`,
/// `TimeoutException`, `DioException` qui aurait échappé au client — est un
/// détail de développeur : il part dans le journal de debug, et le client lit
/// une phrase qu'il peut comprendre. Afficher `type 'Null' is not a subtype
/// of type 'String'` n'aide personne, et expose la structure interne.
///
/// [CartException] et [AuthFailure] sont, comme [ApiException], rédigées pour
/// l'écran : leur message passe tel quel. Tout appel `showErrorSnack` d'un
/// `catch` doit passer par ici — jamais `e.toString()` ni `'Erreur: $e'`
/// (P3-05, garde : `test/common_widgets/no_raw_error_display_test.dart`).
String userFacingErrorMessage(Object error) {
  if (error is ApiException) {
    // Un 500 porte le texte par défaut du framework (« Internal server
    // error »), pas une phrase rédigée pour le client.
    if (error.statusCode == 500) {
      return 'Le service rencontre un problème. Réessayez dans un instant.';
    }
    return error.message;
  }
  if (error is CartException) return error.message;
  if (error is AuthFailure) {
    return error.message.isEmpty
        ? 'Une erreur inattendue est survenue. Réessayez dans un instant.'
        : error.message;
  }

  logDebug('BuildErrorState — erreur non traduite : $error');
  final brut = error.toString();
  if (error is TimeoutException) {
    return 'Le serveur met trop de temps à répondre. Réessayez dans un instant.';
  }
  if (_transport.hasMatch(brut)) {
    return 'Connexion impossible. Vérifiez votre accès à internet.';
  }
  // `Exception('Message pour le client')` : forme encore utilisée par
  // quelques dépôts, dont le texte est rédigé pour l'écran.
  if (error is Exception && brut.startsWith('Exception: ')) {
    return brut.substring('Exception: '.length);
  }
  return 'Une erreur inattendue est survenue. Réessayez dans un instant.';
}

final _transport = RegExp(
  r'SocketException|ClientException|HandshakeException|DioException|'
  r'Failed host lookup|Connection (refused|reset|closed)',
);
