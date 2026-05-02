import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/models/loyalty_transaction.dart';

class UserRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _firebaseAuth.currentUser;
    return await user?.getIdToken();
  }

  Future<AppUser> updateUserProfile(Map<String, dynamic> data) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifie');

    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/users/me'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      return AppUser.fromJson(responseData['user']);
    } else {
      throw Exception('Echec mise a jour profil: ${response.body}');
    }
  }

  Future<AppUser> getUserProfile() async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifie');

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/users/me'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      return AppUser.fromJson(responseData['user']);
    } else {
      throw Exception('Echec chargement profil: ${response.body}');
    }
  }

  Future<ReferralStats> getReferralStats() async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifie');

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/users/me/referral-stats'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return ReferralStats.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Echec chargement parrainage');
    }
  }

  Future<List<LoyaltyTransaction>> getLoyaltyTransactions() async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifie');

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/users/me/loyalty'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final List list = data is List ? data : (data['data'] as List? ?? []);
      return list.map((e) => LoyaltyTransaction.fromJson(e)).toList();
    } else {
      throw Exception('Echec chargement transactions');
    }
  }
}
