import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/models/review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'review_repository.g.dart';

class ReviewRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _firebaseAuth.currentUser;
    return await user?.getIdToken();
  }

  /// Récupérer tous les avis d'un restaurant
  Future<List<Review>> getRestaurantReviews(String restaurantId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reviews/restaurant/$restaurantId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> reviewsJson = data['data'] as List;
        return reviewsJson.map((json) => Review.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load reviews: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting reviews: $e');
      rethrow;
    }
  }

  /// Récupérer les statistiques d'un restaurant
  Future<ReviewStats> getRestaurantStats(String restaurantId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reviews/restaurant/$restaurantId/stats'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ReviewStats.fromJson(data);
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting stats: $e');
      rethrow;
    }
  }

  /// Vérifier si l'utilisateur peut laisser un avis
  Future<CanReviewResponse> canReview(String restaurantId) async {
    final token = await _getIdToken();
    if (token == null) {
      return CanReviewResponse(
        canReview: false,
        reason: 'Vous devez être connecté',
      );
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reviews/restaurant/$restaurantId/can-review'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CanReviewResponse.fromJson(data);
      } else {
        return CanReviewResponse(
          canReview: false,
          reason: 'Erreur lors de la vérification',
        );
      }
    } catch (e) {
      debugPrint('Error checking can review: $e');
      return CanReviewResponse(
        canReview: false,
        reason: 'Erreur de connexion',
      );
    }
  }

  /// Récupérer mon avis pour un restaurant
  Future<Review?> getMyReview(String restaurantId) async {
    final token = await _getIdToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reviews/restaurant/$restaurantId/my-review'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          return Review.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting my review: $e');
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
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Vous devez être connecté');
    }

    try {
      final body = {
        'restaurantId': restaurantId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (orderId != null) 'orderId': orderId,
      };

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Review.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la création');
      }
    } catch (e) {
      debugPrint('Error creating review: $e');
      rethrow;
    }
  }

  /// Mettre à jour un avis
  Future<Review> updateReview({
    required String reviewId,
    int? rating,
    String? comment,
  }) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Vous devez être connecté');
    }

    try {
      final body = <String, dynamic>{};
      if (rating != null) body['rating'] = rating;
      if (comment != null) body['comment'] = comment;

      final response = await http.patch(
        Uri.parse('${AppConstants.baseUrl}/reviews/$reviewId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Review.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la mise à jour');
      }
    } catch (e) {
      debugPrint('Error updating review: $e');
      rethrow;
    }
  }

  /// Supprimer un avis
  Future<void> deleteReview(String reviewId) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Vous devez être connecté');
    }

    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/reviews/$reviewId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la suppression');
      }
    } catch (e) {
      debugPrint('Error deleting review: $e');
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
ReviewRepository reviewRepository(Ref ref) {
  return ReviewRepository();
}
