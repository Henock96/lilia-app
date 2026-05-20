import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;
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
        debugPrint('Jeton détecté. Synchronisation du profil utilisateur...');
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
            _attachSentryUser(response.body);
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
        debugPrint("L'utilisateur est déconnecté, aucun jeton disponible.");
        // Détache l'utilisateur du scope Sentry.
        Sentry.configureScope((scope) => scope.setUser(null));
      }
    });
  }

  /// Attache l'utilisateur (id/email/role) au scope Sentry pour que les
  /// erreurs remontées soient associées au bon compte. Réponse de
  /// `GET /users/me` : `{ user: { id, email, role, ... } }`.
  void _attachSentryUser(String responseBody) {
    try {
      final user = jsonDecode(responseBody)['user'] as Map<String, dynamic>?;
      if (user == null) return;
      Sentry.configureScope(
        (scope) => scope.setUser(
          SentryUser(
            id: user['id'] as String?,
            email: user['email'] as String?,
            data: {'role': user['role']},
          ),
        ),
      );
    } catch (_) {
      // Parsing best-effort : ne jamais casser la sync pour le contexte Sentry.
    }
  }
}
