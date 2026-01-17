import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/reviews/data/review_repository.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/star_rating.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String? existingReviewId;

  const WriteReviewScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.existingReviewId,
  });

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingReviewId != null;
    if (_isEditing) {
      _loadExistingReview();
    }
  }

  Future<void> _loadExistingReview() async {
    try {
      final review = await ref
          .read(reviewRepositoryProvider)
          .getMyReview(widget.restaurantId);

      if (review != null && mounted) {
        setState(() {
          _rating = review.rating;
          _commentController.text = review.comment ?? '';
        });
      }
    } catch (e) {
      // Ignorer l'erreur
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier mon avis' : 'Laisser un avis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom du restaurant
            Text(
              widget.restaurantName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Section note
            const Text(
              'Votre note',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: StarRatingInput(
                rating: _rating,
                onRatingChanged: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
                size: 48,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getRatingText(_rating),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Section commentaire
            const Text(
              'Votre commentaire (optionnel)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Partagez votre experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton de soumission
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating > 0 && !_isLoading ? _submitReview : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isEditing ? 'Modifier mon avis' : 'Publier mon avis',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            if (_rating == 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Veuillez selectionner une note',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Tres insatisfait';
      case 2:
        return 'Insatisfait';
      case 3:
        return 'Correct';
      case 4:
        return 'Satisfait';
      case 5:
        return 'Tres satisfait';
      default:
        return 'Selectionnez une note';
    }
  }

  Future<void> _submitReview() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(reviewRepositoryProvider);

      if (_isEditing && widget.existingReviewId != null) {
        await repository.updateReview(
          reviewId: widget.existingReviewId!,
          rating: _rating,
          comment: _commentController.text.trim(),
        );
      } else {
        await repository.createReview(
          restaurantId: widget.restaurantId,
          rating: _rating,
          comment: _commentController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Avis modifie avec succes' : 'Merci pour votre avis !',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
