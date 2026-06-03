import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quartiers_repository.g.dart';

@Riverpod(keepAlive: true)
class QuartiersRepository extends _$QuartiersRepository {
  @override
  Future<void> build() async {
    return;
  }

  /// Récupère la liste de tous les quartiers
  Future<List<Quartier>> getAllQuartiers() async {
    final token = await ref.read(firebaseIdTokenProvider.future);

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/quartiers'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      // /quartiers est double-enveloppé par l'interceptor backend
      // (`{ data: { data: [...], count } }`). Déballe l'externe puis lit la liste.
      final quartiersJson = ApiResponse.listOf(ApiResponse.mapOf(decoded));
      return quartiersJson.map((json) => Quartier.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors du chargement des quartiers: ${response.body}');
    }
  }

  /// Calcule les frais de livraison pour un restaurant et un quartier
  Future<DeliveryFeeResult> calculateDeliveryFee({
    required String restaurantId,
    required String quartierId,
  }) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Utilisateur non authentifié');
    }

    final response = await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/quartiers/delivery-fee?restaurantId=$restaurantId&quartierId=$quartierId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      // Objet plat côté service → enveloppé `{ data: {...} }` par l'interceptor.
      return DeliveryFeeResult.fromJson(ApiResponse.mapOf(decoded));
    } else {
      throw Exception('Erreur lors du calcul des frais: ${response.body}');
    }
  }
}
