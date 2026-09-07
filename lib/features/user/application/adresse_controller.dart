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

  // Méthode pour créer une adresse
  Future<Adresse> createAdresse({
    required String rue,
    String ville = 'Brazzaville',
    String pays = 'Congo',
    String? quartierId,
    double? latitude,
    double? longitude,
    String? landmark,
    String? label,
  }) async {
    try {
      final adresseRepo = ref.read(adresseRepositoryProvider.notifier);
      final adresse = await adresseRepo.createAdresse(
        rue: rue,
        ville: ville,
        pays: pays,
        quartierId: quartierId,
        latitude: latitude,
        longitude: longitude,
        landmark: landmark,
        label: label,
      );
      ref.invalidateSelf(); // Rafraîchir la liste
      return adresse;
    } catch (e) {
      rethrow;
    }
  }

  /// Complète a posteriori la position d'une adresse existante.
  Future<Adresse> updatePosition(
    String adresseId, {
    required double latitude,
    required double longitude,
    String? landmark,
  }) async {
    final adresseRepo = ref.read(adresseRepositoryProvider.notifier);
    final adresse = await adresseRepo.updatePosition(
      adresseId,
      latitude: latitude,
      longitude: longitude,
      landmark: landmark,
    );
    ref.invalidateSelf();
    return adresse;
  }

  /// Modifie le libellé, la rue ou le quartier d'une adresse existante.
  Future<Adresse> updateAdresse(
    String adresseId, {
    String? rue,
    String? quartierId,
    String? label,
  }) async {
    final adresseRepo = ref.read(adresseRepositoryProvider.notifier);
    final adresse = await adresseRepo.updateAdresse(
      adresseId,
      rue: rue,
      quartierId: quartierId,
      label: label,
    );
    ref.invalidateSelf();
    return adresse;
  }

  /// Désigne l'adresse par défaut.
  ///
  /// On recharge la liste entière plutôt que de basculer le drapeau localement :
  /// l'opération en modifie **plusieurs** lignes côté serveur (l'ancienne
  /// défaut repasse à `false`), et deviner ce basculement ici finirait par
  /// diverger de ce que la base contient réellement.
  Future<void> setDefault(String adresseId) async {
    final adresseRepo = ref.read(adresseRepositoryProvider.notifier);
    await adresseRepo.setDefault(adresseId);
    ref.invalidateSelf();
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
