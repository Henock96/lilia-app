import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
          final res = await ref.read(apiClientProvider).getJson('/users/me');
          if (kDebugMode) {
            // Status only — never log the token nor the response body
            // (contains user PII).
            debugPrint('Backend /users/me sync status: ${res.statusCode}');
          }
        } on ApiException catch (e) {
          if (kDebugMode) {
            debugPrint('Backend sync error: ${e.kind}');
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
