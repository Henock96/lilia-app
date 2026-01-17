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

  //final String _baseUrl = 'https://lilia-backend.onrender.com';

  Future<List<Adresse>> getUserAdresses() async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('User not authenticated. No Firebase ID token available.');
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
        List<dynamic> addressesJson = json.decode(response.body);
        return addressesJson.map((json) => Adresse.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user addresses: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server or fetch addresses: $e');
    }
  }

  Future<Adresse> createAdresse({required String rue, required String ville, required String pays}) async {
    Map<String, dynamic> data = {
      "rue": rue,
      "ville": ville,
      "country": pays
    };
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('User not authenticated. No Firebase ID token available.');
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
        var addressesJson = json.decode(response.body);
        return Adresse.fromJson(addressesJson);
      } else {
        throw Exception('Failed to load user addresses: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server or fetch addresses: $e');
    }
  }

  Future<void> deleteAdresse(String adresseId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('User not authenticated. No Firebase ID token available.');
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
        throw Exception('Failed to delete address: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server or delete address: $e');
    }
  }
}