import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/models/promo_validation_result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'promo_repository.g.dart';

@riverpod
class PromoRepository extends _$PromoRepository {
  @override
  FutureOr<void> build() => null;

  /// Valide un code promo auprès du backend.
  ///
  /// Retourne un [PromoValidationResult] si le code est valide,
  /// ou lève une [Exception] avec le message d'erreur du backend.
  Future<PromoValidationResult> validateCode({
    required String code,
    required String restaurantId,
    required double subTotal,
    required double deliveryFee,
  }) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/promo/validate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'code': code.trim().toUpperCase(),
        'restaurantId': restaurantId,
        'subTotal': subTotal,
        'deliveryFee': deliveryFee,
      }),
    );

    final body = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return PromoValidationResult.fromJson(body as Map<String, dynamic>);
    }

    // Extraire le message d'erreur du backend
    final message = body is Map<String, dynamic>
        ? (body['message'] as String?) ?? 'Code promo invalide.'
        : 'Code promo invalide.';
    throw Exception(message);
  }
}
