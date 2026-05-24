import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:http/http.dart' as http;

part 'user_sync_provider.g.dart';

@riverpod
class UserDataSynchronizer extends _$UserDataSynchronizer {
  @override
  Future<void> build() async {
    ref.listen(firebaseIdTokenProvider, (previous, next) async {
      final token = next.value;

      if (token != null) {
        // Un token est disponible, l'utilisateur est probablement connecté.
        // On lance la synchronisation.
        debugPrint('Jeton détecté. Synchronisation du profil utilisateur...');

        // Contexte Sentry : rattacher les erreurs à l'utilisateur connecté.
        // Rôle constant CLIENT pour cette app.
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await Sentry.configureScope(
            (scope) => scope.setUser(
              SentryUser(
                id: firebaseUser.uid,
                email: firebaseUser.email,
                data: const {'role': 'CLIENT'},
              ),
            ),
          );
        }

        try {
          final response = await http.get(
            Uri.parse('${AppConstants.baseUrl}/users/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            debugPrint('Synchronisation du backend réussie. $token');
          } else {
            debugPrint(
              'Erreur lors de lappel de synchronisation du backend ${response.statusCode} - ${response.body}',
            );
          }
        } catch (e) {
          debugPrint('Error during backend synchronization call: $e');
        }
      } else {
        // Pas de token, l'utilisateur est déconnecté.
        // Purger le contexte Sentry au logout.
        await Sentry.configureScope((scope) => scope.setUser(null));
        debugPrint("L'utilisateur est déconnecté, aucun jeton disponible.");
      }
    });
  }
}
