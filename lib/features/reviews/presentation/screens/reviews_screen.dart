import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/reviews/data/review_controller.dart';
import 'package:lilia_app/features/reviews/data/review_repository.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/review_card.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/star_rating.dart';
import 'package:lilia_app/features/reviews/presentation/screens/write_review_screen.dart';

import '../../../../models/review.dart';

class ReviewsScreen extends ConsumerWidget {
  final String restaurantId;
  final String restaurantName;

  const ReviewsScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(restaurantReviewsProvider(restaurantId));
    final statsAsync = ref.watch(restaurantStatsProvider(restaurantId));
    final canReviewAsync = ref.watch(canReviewProvider(restaurantId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Avis - $restaurantName'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantReviewsProvider(restaurantId));
          ref.invalidate(restaurantStatsProvider(restaurantId));
          ref.invalidate(canReviewProvider(restaurantId));
        },
        child: CustomScrollView(
          slivers: [
            // Section statistiques
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => _StatsSection(stats: stats),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Bouton pour ajouter un avis
            SliverToBoxAdapter(
              child: canReviewAsync.when(
                data: (canReview) {
                  if (canReview.canReview) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToWriteReview(context, ref),
                        icon: const Icon(Icons.rate_review),
                        label: const Text('Laisser un avis'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    );
                  } else if (canReview.existingReviewId != null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToWriteReview(
                          context,
                          ref,
                          existingReviewId: canReview.existingReviewId,
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier mon avis'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                canReview.reason ?? 'Vous ne pouvez pas laisser d\'avis',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Titre de la section avis
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Tous les avis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Liste des avis
            reviewsAsync.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun avis pour le moment',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Soyez le premier à donner votre avis !',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final review = reviews[index];
                      return ReviewCard(
                        review: review,
                        // TODO: Vérifier si c'est l'avis de l'utilisateur connecté
                        isOwner: false,
                        onEdit: () => _navigateToWriteReview(
                          context,
                          ref,
                          existingReviewId: review.id,
                        ),
                        onDelete: () => _deleteReview(context, ref, review.id),
                      );
                    },
                    childCount: reviews.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          restaurantReviewsProvider(restaurantId),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToWriteReview(
    BuildContext context,
    WidgetRef ref, {
    String? existingReviewId,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => WriteReviewScreen(
          restaurantId: restaurantId,
          restaurantName: restaurantName,
          existingReviewId: existingReviewId,
        ),
      ),
    );

    if (result == true) {
      ref.invalidate(restaurantReviewsProvider(restaurantId));
      ref.invalidate(restaurantStatsProvider(restaurantId));
      ref.invalidate(canReviewProvider(restaurantId));
    }
  }

  void _deleteReview(BuildContext context, WidgetRef ref, String reviewId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'avis'),
        content: const Text('Voulez-vous vraiment supprimer cet avis ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(reviewRepositoryProvider).deleteReview(reviewId);
                ref.invalidate(restaurantReviewsProvider(restaurantId));
                ref.invalidate(restaurantStatsProvider(restaurantId));
                ref.invalidate(canReviewProvider(restaurantId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avis supprimé')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final ReviewStats stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Note moyenne
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  stats.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StarRating(rating: stats.averageRating, size: 24),
                const SizedBox(height: 4),
                Text(
                  '${stats.totalReviews} avis',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Distribution des notes
          Expanded(
            flex: 3,
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = stats.ratingDistribution[star] ?? 0;
                final percentage = stats.totalReviews > 0
                    ? count / stats.totalReviews
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(fontSize: 12)),
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
