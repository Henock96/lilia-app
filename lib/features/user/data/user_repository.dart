import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/models/loyalty_transaction.dart';
import 'package:lilia_app/utils/api_response.dart';

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
      return AppUser.fromJson(_extractUser(responseData));
    } else {
      throw Exception('Echec mise a jour profil: ${response.body}');
    }
  }

  /// Extrait l'objet user de la réponse `/users/me`, tolérant aux deux formes :
  /// legacy `{ user: {...} }` ET wrappée api-contract-v2 `{ data: { user: {...} } }`.
  Map<String, dynamic> _extractUser(dynamic decoded) {
    final unwrapped = ApiResponse.mapOf(decoded); // { data: { user } } -> { user }
    final user = unwrapped['user'] ?? unwrapped;
    return user as Map<String, dynamic>;
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
      return AppUser.fromJson(_extractUser(responseData));
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
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      // Objet plat côté backend → wrappé en `{ data: {...} }` par l'interceptor.
      return ReferralStats.fromJson(ApiResponse.mapOf(decoded));
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
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return ApiResponse.listOf(decoded)
          .map((e) => LoyaltyTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Echec chargement transactions');
    }
  }
}
