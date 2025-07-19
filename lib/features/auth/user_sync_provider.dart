import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http; // Exemple, utilisez votre client HTTP préféré

part 'user_sync_provider.g.dart';

// Un provider pour gérer la synchronisation des données utilisateur avec le backend
@Riverpod(keepAlive: true) // Gardez ce synchronisateur actif
class UserDataSynchronizer extends _$UserDataSynchronizer {
  @override
  Future<void> build() async {
    // Écoutez les changements du jeton ID
    ref.listen(firebaseIdTokenProvider, (previousToken, newTokenAsyncValue) async {
      final newToken = newTokenAsyncValue.value; // Accédez à la valeur du jeton

      if (newToken != null) {
        // L'utilisateur est connecté et nous avons un jeton valide
        print('Jeton ID obtenu (pour envoi au backend) : $newToken');

        try {
          // --- C'EST ICI QUE VOUS APPELEZ VOTRE BACKEND NEST.JS ---
          final response = await http.get(
            Uri.parse('https://lilia-app.fly.dev/auth/profile'), // ADAPTEZ L'URL DE VOTRE ENDPOINT
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken', // ENVOYEZ LE JETON ID ICI !
            },
          );

          if (response.statusCode == 200) {
            print('Synchronisation backend réussie pour l\'utilisateur.');
            // Si votre backend retourne des informations utilisateur mises à jour,
            // vous pouvez les gérer ici ou les stocker dans un autre provider.
          } else {
            print('Erreur de synchronisation backend : ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Erreur lors de l\'appel backend de synchronisation : $e');
        }
      } else {
        // L'utilisateur est déconnecté ou le jeton n'est plus valide
        print('Jeton ID non disponible (utilisateur déconnecté ou jeton invalide).');
        // Optionnel : Nettoyez les données utilisateur locales si l'utilisateur se déconnecte
      }
    });

    // Pas d'état interne à maintenir pour ce Notifier, il s'agit principalement d'effets secondaires
    return;
  }
}
