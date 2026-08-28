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

  Future<Adresse> createAdresse({
    required String rue,
    required String ville,
    required String pays,
    String? quartierId,
  }) async {
    final data = <String, dynamic>{
      "rue": rue,
      "ville": ville,
      "country": pays,
      if (quartierId != null) "quartierId": quartierId,
    };
    final res = await _api.postJson('/adresses', body: data);
    return Adresse.fromJson(ApiResponse.mapOf(res.data));
  }

  Future<void> deleteAdresse(String adresseId) async {
    await _api.deleteJson('/adresses/$adresseId');
  }
}
