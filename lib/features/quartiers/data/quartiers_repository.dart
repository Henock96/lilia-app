import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quartiers_repository.g.dart';

@Riverpod(keepAlive: true)
class QuartiersRepository extends _$QuartiersRepository {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<void> build() async {
    return;
  }

  /// Récupère la liste de tous les quartiers
  Future<List<Quartier>> getAllQuartiers() async {
    final res = await _api.getJson('/quartiers');
    // /quartiers est double-enveloppé par l'interceptor backend
    // (`{ data: { data: [...], count } }`). Déballe l'externe puis lit la liste.
    final quartiersJson = ApiResponse.listOf(ApiResponse.mapOf(res.data));
    return quartiersJson
        .map((json) => Quartier.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Calcule les frais de livraison pour un restaurant et un quartier
  Future<DeliveryFeeResult> calculateDeliveryFee({
    required String restaurantId,
    required String quartierId,
  }) async {
    final res = await _api.getJson(
      '/quartiers/delivery-fee',
      query: {'restaurantId': restaurantId, 'quartierId': quartierId},
    );
    // Objet plat côté service → enveloppé `{ data: {...} }` par l'interceptor.
    return DeliveryFeeResult.fromJson(ApiResponse.mapOf(res.data));
  }
}
