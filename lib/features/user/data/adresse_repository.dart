// lib/repositories/address_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'adresse_repository.g.dart';

@Riverpod(keepAlive: true)
class AdresseRepository extends _$AdresseRepository {
  @override
  Future<void> build() async {
    return;
  }

  final String _baseUrl = 'http://10.0.2.2:3000';

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
}