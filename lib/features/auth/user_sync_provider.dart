import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
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
        print('Jeton détecté. Synchronisation du profil utilisateur...');
        try {
          final response = await http.get(
            Uri.parse('https://lilia-backend.onrender.com/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            print('Synchronisation du backend réussie. $token');
          } else {
            print('Erreur lors de lappel de synchronisation du backend ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Error during backend synchronization call: $e');
        }
      } else {
        // Pas de token, l'utilisateur est déconnecté.
        print("L'utilisateur est déconnecté, aucun jeton disponible.");
      }
    });
  }
}

