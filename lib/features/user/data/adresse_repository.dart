// lib/repositories/address_repository.dart
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/adresse.dart';

part 'adresse_repository.g.dart';

@riverpod
class AdresseRepository extends _$AdresseRepository {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<void> build() async {
    return;
  }

  Future<List<Adresse>> getUserAdresses() async {
    final res = await _api.getJson('/adresses');
    // /adresses double-enveloppé (`{ data: { data: [...], count } }`).
    final addressesJson = ApiResponse.listOf(ApiResponse.mapOf(res.data));
    return addressesJson
        .map((json) => Adresse.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Crée une adresse.
  ///
  /// [latitude] / [longitude] sont la position **de l'adresse**, posée par le
  /// client sur la carte — jamais la position courante du téléphone. Le
  /// serveur les valide (bornes du Congo, inversion, `(0, 0)`) et refuse en
  /// 400 ce qui ne tient pas debout.
  Future<Adresse> createAdresse({
    required String rue,
    required String ville,
    required String pays,
    String? quartierId,
    double? latitude,
    double? longitude,
    String? landmark,
    String? label,
  }) async {
    final data = <String, dynamic>{
      "rue": rue,
      "ville": ville,
      "country": pays,
      "quartierId": ?quartierId,
      "latitude": ?latitude,
      "longitude": ?longitude,
      if (landmark != null && landmark.isNotEmpty) "landmark": landmark,
      if (label != null && label.isNotEmpty) "label": label,
    };
    final res = await _api.postJson('/adresses', body: data);
    return Adresse.fromJson(ApiResponse.mapOf(res.data));
  }

  /// Met à jour la position d'une adresse existante.
  ///
  /// Sert au rattrapage des adresses créées avant que la position existe :
  /// l'écran « Mes adresses » propose « Situer sur la carte » sur chacune
  /// d'elles, plutôt que d'obliger le client à la recréer.
  Future<Adresse> updatePosition(
    String adresseId, {
    required double latitude,
    required double longitude,
    String? landmark,
  }) async {
    final res = await _api.patchJson(
      '/adresses/$adresseId',
      body: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        // `null` est transmis délibérément — il **efface** les repères.
        //
        // La condition précédente (`!= null && isNotEmpty`) omettait le champ
        // dans ce cas, et le serveur laissait donc l'ancienne valeur en place :
        // un client qui effaçait « portail bleu » parce qu'il avait déménagé
        // de porte voyait le texte revenir, sans aucun moyen de s'en défaire.
        // L'écran de choix de position porte ce champ pré-rempli : ce qu'il
        // rend fait autorité, y compris quand c'est vide.
        'landmark': landmark,
      },
    );
    return Adresse.fromJson(ApiResponse.mapOf(res.data));
  }

  /// Modifie le contenu d'une adresse : libellé, rue, quartier.
  ///
  /// Cette méthode manquait, et son absence se voyait à l'usage : une adresse
  /// enregistrée était **définitive**. Une faute de frappe dans le nom de rue,
  /// un quartier choisi trop vite, un « Maison » qu'on voulait appeler
  /// « Chez maman » — la seule issue était de supprimer puis recréer, ce qui
  /// faisait aussi perdre la position déjà posée sur la carte.
  ///
  /// Les paramètres omis ne sont pas envoyés : le serveur ne réécrit que ce
  /// qu'il reçoit. C'est ce qui permet de corriger le libellé sans toucher à
  /// la position, et inversement.
  Future<Adresse> updateAdresse(
    String adresseId, {
    String? rue,
    String? quartierId,
    String? label,
  }) async {
    final res = await _api.patchJson(
      '/adresses/$adresseId',
      body: <String, dynamic>{
        'rue': ?rue,
        'quartierId': ?quartierId,
        // Chaîne vide volontairement transmise : c'est ainsi que le client
        // efface un libellé qu'il ne veut plus. Seul `null` omet le champ.
        'label': ?label,
      },
    );
    return Adresse.fromJson(ApiResponse.mapOf(res.data));
  }

  /// Désigne l'adresse par défaut du client.
  ///
  /// Le serveur bascule les autres à `false` dans une transaction : il n'y a
  /// jamais deux adresses par défaut, et jamais zéro tant qu'une a été
  /// choisie.
  Future<void> setDefault(String adresseId) async {
    await _api.patchJson('/adresses/$adresseId/default');
  }

  Future<void> deleteAdresse(String adresseId) async {
    await _api.deleteJson('/adresses/$adresseId');
  }
}
