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
      if (quartierId != null) "quartierId": quartierId,
      if (latitude != null) "latitude": latitude,
      if (longitude != null) "longitude": longitude,
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
        if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
      },
    );
    return Adresse.fromJson(ApiResponse.mapOf(res.data));
  }

  Future<void> deleteAdresse(String adresseId) async {
    await _api.deleteJson('/adresses/$adresseId');
  }
}
