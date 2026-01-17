import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';

class UserRepository {
  //final String _baseUrl = 'https://lilia-backend.onrender.com'; // Mettez votre URL de base ici
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _firebaseAuth.currentUser;
    return await user?.getIdToken();
  }

  Future<AppUser> updateUserProfile(Map<String, dynamic> data) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Utilisateur non authentifié');
    }

    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return AppUser.fromJson(responseData['user']);
    } else {
      throw Exception('Échec de la mise à jour du profil: ${response.body}');
    }
  }

  Future<AppUser> getUserProfile() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Utilisateur non authentifié');
    }

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return AppUser.fromJson(responseData["localDbInfo"]);
    } else {
      throw Exception('Échec de la mise à jour du profil: ${response.body}');
    }
  }
}