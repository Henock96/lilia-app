import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/models/promo_validation_result.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'promo_repository.g.dart';

@riverpod
class PromoRepository extends _$PromoRepository {
  @override
  FutureOr<void> build() => null;

  /// Valide un code promo auprès du backend.
  ///
  /// Retourne un [PromoValidationResult] si le code est valide, ou lève une
  /// [ApiException] (message backend) si invalide.
  Future<PromoValidationResult> validateCode({
    required String code,
    required String restaurantId,
    required double subTotal,
    required double deliveryFee,
  }) async {
    final res = await ref
        .read(apiClientProvider)
        .postJson(
          '/promo/validate',
          body: {
            'code': code.trim().toUpperCase(),
            'restaurantId': restaurantId,
            'subTotal': subTotal,
            'deliveryFee': deliveryFee,
          },
        );
    // Objet plat côté backend → enveloppé `{ data: {...} }` par l'interceptor.
    return PromoValidationResult.fromJson(ApiResponse.mapOf(res.data));
  }
}
