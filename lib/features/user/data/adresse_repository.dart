// lib/repositories/address_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/adresse.dart';

part 'adresse_repository.g.dart';

@riverpod
class AdresseRepository extends _$AdresseRepository {
  @override
  Future<void> build() async {
    return;
  }

  Future<List<Adresse>> getUserAdresses() async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/adresses'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> addressesJson = decoded['data'];
        return addressesJson.map((json) => Adresse.fromJson(json)).toList();
      } else {
        throw Exception('Impossible de charger vos adresses.');
      }
    } on http.ClientException {
      throw Exception('Problème de connexion. Vérifiez votre internet.');
    }
  }

  Future<Adresse> createAdresse({
    required String rue,
    required String ville,
    required String pays,
    String? quartierId,
  }) async {
    Map<String, dynamic> data = {
      "rue": rue,
      "ville": ville,
      "country": pays,
    };
    if (quartierId != null) {
      data["quartierId"] = quartierId;
    }
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/adresses'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        final decoded = json.decode(response.body);
        return Adresse.fromJson(decoded['data']);
      } else {
        throw Exception('Impossible de sauvegarder l\'adresse.');
      }
    } on http.ClientException {
      throw Exception('Problème de connexion. Vérifiez votre internet.');
    }
  }

  Future<void> deleteAdresse(String adresseId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/adresses/$adresseId'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Impossible de supprimer l\'adresse.');
      }
    } on http.ClientException {
      throw Exception('Problème de connexion. Vérifiez votre internet.');
    }
  }
}
