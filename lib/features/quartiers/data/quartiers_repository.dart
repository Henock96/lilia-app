import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/models/quartier.dart';
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
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/quartiers'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final List<dynamic> quartiersJson = data['data'];
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
      final data = json.decode(utf8.decode(response.bodyBytes));
      return DeliveryFeeResult.fromJson(data);
    } else {
      throw Exception('Erreur lors du calcul des frais: ${response.body}');
    }
  }
}
