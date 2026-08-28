import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/models/loyalty_transaction.dart';
import 'package:lilia_app/utils/api_response.dart';

class UserRepository {
  final ApiClient _api;

  UserRepository(this._api);

  Future<AppUser> updateUserProfile(Map<String, dynamic> data) async {
    final res = await _api.putJson('/users/me', body: data);
    return AppUser.fromJson(_extractUser(res.data));
  }

  /// Extrait l'objet user de la réponse `/users/me`, tolérant aux deux formes :
  /// legacy `{ user: {...} }` ET wrappée api-contract-v2 `{ data: { user: {...} } }`.
  Map<String, dynamic> _extractUser(dynamic decoded) {
    final unwrapped = ApiResponse.mapOf(
      decoded,
    ); // { data: { user } } -> { user }
    final user = unwrapped['user'] ?? unwrapped;
    return user as Map<String, dynamic>;
  }

  Future<AppUser> getUserProfile() async {
    final res = await _api.getJson('/users/me');
    return AppUser.fromJson(_extractUser(res.data));
  }

  Future<ReferralStats> getReferralStats() async {
    final res = await _api.getJson('/users/me/referral-stats');
    // Objet plat côté backend → wrappé en `{ data: {...} }` par l'interceptor.
    return ReferralStats.fromJson(ApiResponse.mapOf(res.data));
  }

  Future<List<LoyaltyTransaction>> getLoyaltyTransactions() async {
    final res = await _api.getJson('/users/me/loyalty');
    return ApiResponse.listOf(res.data)
        .map((e) => LoyaltyTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
