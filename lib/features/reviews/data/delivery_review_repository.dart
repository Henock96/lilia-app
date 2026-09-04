import 'package:flutter/foundation.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delivery_review_repository.g.dart';

/// Note laissée par le client sur une livraison.
///
/// Distincte de [Review], qui note un vendeur : le backend a deux modèles
/// séparés parce qu'une même commande peut donner lieu aux deux notes.
class DeliveryReview {
  final String id;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  const DeliveryReview({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory DeliveryReview.fromJson(Map<String, dynamic> json) {
    return DeliveryReview(
      id: json['id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

class DeliveryReviewRepository {
  final ApiClient _api;

  DeliveryReviewRepository(this._api);

  /// Note le livreur d'une livraison terminée (1 à 5 étoiles).
  ///
  /// Le backend refuse — et c'est voulu — une note sur une livraison qui n'est
  /// pas `LIVRER`, une livraison qui n'appartient pas au client, ou une
  /// seconde note sur la même livraison (409).
  Future<DeliveryReview> rateDriver({
    required String deliveryId,
    required int rating,
    String? comment,
  }) async {
    final res = await _api.postJson(
      '/delivery-reviews',
      body: {
        'deliveryId': deliveryId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
    return DeliveryReview.fromJson(ApiResponse.mapOf(res.data));
  }

  /// Note déjà laissée sur cette livraison, ou `null`.
  ///
  /// Dégrade en `null` plutôt que de lever : ne pas savoir si une note existe
  /// ne doit pas empêcher d'afficher la commande.
  Future<DeliveryReview?> getForDelivery(String deliveryId) async {
    try {
      final res = await _api.getJson('/delivery-reviews/by-delivery/$deliveryId');
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data == null) return null;
      return DeliveryReview.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      debugPrint('[DeliveryReview] lecture impossible : ${e.message}');
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
DeliveryReviewRepository deliveryReviewRepository(Ref ref) {
  return DeliveryReviewRepository(ref.watch(apiClientProvider));
}
