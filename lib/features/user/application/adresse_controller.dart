// lib/controllers/user_addresses_controller.dart
import 'package:lilia_app/features/user/data/adresse_repository.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'adresse_controller.g.dart';

@Riverpod(keepAlive: true)
class AdresseController extends _$AdresseController {
  @override
  Future<List<Adresse>> build() async {
    final repository = ref.watch(adresseRepositoryProvider.notifier);
    return repository.getUserAdresses();
  }

  // Méthode pour annuler une commande
  Future<Adresse> createAdresse({
    required String rue,
    String ville = 'Brazzaville',
    String pays = 'Congo',
  }) async {
    // On ne change pas l'état ici pour éviter un rechargement de toute la liste
    // On va juste appeler le repo et rafraîchir la liste après
    try {
      final adresseRepo = ref.read(adresseRepositoryProvider.notifier);
      return adresseRepo.createAdresse(rue: rue, ville: ville, pays: pays);
      // Rafraîchir la liste pour refléter le changement de statut
    } catch (e) {
      // Propage l'erreur pour que l'UI puisse l'afficher
      rethrow;
    }
  }

  Future<void> deleteAdresse(String adresseId) async {
    try {
      final adresseRepo = ref.read(adresseRepositoryProvider.notifier);
      await adresseRepo.deleteAdresse(adresseId);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }
}
