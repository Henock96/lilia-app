import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
        if (kDebugMode) {
          debugPrint('Token detected. Syncing user profile...');
        }

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

          if (kDebugMode) {
            // Status only — never log the token nor the response body
            // (contains user PII).
            debugPrint('Backend /users/me sync status: ${response.statusCode}');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Backend sync error: ${e.runtimeType}');
          }
        }
      } else {
        // Pas de token, l'utilisateur est déconnecté.
        // Purger le contexte Sentry au logout.
        await Sentry.configureScope((scope) => scope.setUser(null));
        if (kDebugMode) {
          debugPrint('User signed out, no token available.');
        }
      }
    });
  }
}
