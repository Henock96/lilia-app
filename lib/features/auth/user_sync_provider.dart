import 'package:flutter/widgets.dart';
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
        try {
          final response = await http.get(
            Uri.parse('${AppConstants.baseUrl}/auth/profile'),
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
        debugPrint("L'utilisateur est déconnecté, aucun jeton disponible.");
      }
    });
  }
}
