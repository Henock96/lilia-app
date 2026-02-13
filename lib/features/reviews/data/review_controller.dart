import 'package:lilia_app/features/reviews/data/review_repository.dart';
import 'package:lilia_app/models/review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'review_controller.g.dart';

/// Provider pour récupérer les avis d'un restaurant
@riverpod
Future<List<Review>> restaurantReviews(Ref ref, String restaurantId) async {
  final repository = ref.watch(reviewRepositoryProvider);
  return repository.getRestaurantReviews(restaurantId);
}

/// Provider pour récupérer les statistiques d'un restaurant
@riverpod
Future<ReviewStats> restaurantStats(Ref ref, String restaurantId) async {
  final repository = ref.watch(reviewRepositoryProvider);
  return repository.getRestaurantStats(restaurantId);
}

/// Provider pour vérifier si l'utilisateur peut laisser un avis
@riverpod
Future<CanReviewResponse> canReview(Ref ref, String restaurantId) async {
  final repository = ref.watch(reviewRepositoryProvider);
  return repository.canReview(restaurantId);
}

/// Provider pour récupérer mon avis
@riverpod
Future<Review?> myReview(Ref ref, String restaurantId) async {
  final repository = ref.watch(reviewRepositoryProvider);
  return repository.getMyReview(restaurantId);
}
