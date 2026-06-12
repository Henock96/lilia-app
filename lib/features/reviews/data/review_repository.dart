import 'package:flutter/foundation.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/models/review.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'review_repository.g.dart';

class ReviewRepository {
  final ApiClient _api;

  ReviewRepository(this._api);

  /// Récupérer tous les avis d'un restaurant
  Future<List<Review>> getRestaurantReviews(String restaurantId) async {
    final res = await _api.getJson('/reviews/restaurant/$restaurantId');
    // Liste possiblement double-enveloppée (`{ data: { data: [...], ... } }`).
    final reviewsJson = ApiResponse.listOf(ApiResponse.mapOf(res.data));
    return reviewsJson.map((json) => Review.fromJson(json)).toList();
  }

  /// Récupérer les statistiques d'un restaurant
  Future<ReviewStats> getRestaurantStats(String restaurantId) async {
    final res = await _api.getJson('/reviews/restaurant/$restaurantId/stats');
    // Objet plat → enveloppé `{ data: {...} }` par l'interceptor.
    return ReviewStats.fromJson(ApiResponse.mapOf(res.data));
  }

  /// Vérifier si l'utilisateur peut laisser un avis.
  /// Dégrade gracieusement : renvoie un refus motivé plutôt que de lever.
  Future<CanReviewResponse> canReview(String restaurantId) async {
    try {
      final res =
          await _api.getJson('/reviews/restaurant/$restaurantId/can-review');
      // Objet plat → enveloppé `{ data: {...} }` par l'interceptor.
      return CanReviewResponse.fromJson(ApiResponse.mapOf(res.data));
    } on ApiException catch (e) {
      debugPrint('canReview: ${e.message}');
      final reason = e.kind == ApiErrorKind.unauthorized
          ? 'Vous devez être connecté'
          : 'Erreur lors de la vérification';
      return CanReviewResponse(canReview: false, reason: reason);
    }
  }

  /// Récupérer mon avis pour un restaurant (null si absent ou non connecté).
  Future<Review?> getMyReview(String restaurantId) async {
    try {
      final res =
          await _api.getJson('/reviews/restaurant/$restaurantId/my-review');
      final data = res.data;
      if (data is Map && data['data'] != null) {
        return Review.fromJson(data['data']);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('getMyReview: ${e.message}');
      return null;
    }
  }

  /// Créer un avis
  Future<Review> createReview({
    required String restaurantId,
    required int rating,
    String? comment,
    String? orderId,
  }) async {
    final body = {
      'restaurantId': restaurantId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (orderId != null) 'orderId': orderId,
    };
    final res = await _api.postJson('/reviews', body: body);
    return Review.fromJson((res.data as Map<String, dynamic>)['data']);
  }

  /// Mettre à jour un avis
  Future<Review> updateReview({
    required String reviewId,
    int? rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{};
    if (rating != null) body['rating'] = rating;
    if (comment != null) body['comment'] = comment;

    final res = await _api.patchJson('/reviews/$reviewId', body: body);
    return Review.fromJson((res.data as Map<String, dynamic>)['data']);
  }

  /// Supprimer un avis
  Future<void> deleteReview(String reviewId) async {
    await _api.deleteJson('/reviews/$reviewId');
  }
}

@Riverpod(keepAlive: true)
ReviewRepository reviewRepository(Ref ref) {
  return ReviewRepository(ref.watch(apiClientProvider));
}
