// lib/repositories/address_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'adresse_repository.g.dart';

@riverpod
class AdresseRepository extends _$AdresseRepository {
  @override
  Future<void> build() async {
    return;
  }

  final String _baseUrl = 'https://lilia-app.fly.dev';

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
        Uri.parse('$_baseUrl/adresses'),
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

  Future<Adresse> createAdresse({required String rue, required String ville, required String pays, required String details}) async {
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
        Uri.parse('$_baseUrl/adresses'),
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

}