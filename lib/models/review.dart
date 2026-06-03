class Review {
  final String id;
  final int rating;
  final String? comment;
  final String userId;
  final String restaurantId;
  final String? orderId;
  final ReviewUser user;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.rating,
    this.comment,
    required this.userId,
    required this.restaurantId,
    this.orderId,
    required this.user,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      userId: json['userId'] as String? ?? '',
      restaurantId: json['restaurantId'] as String? ?? '',
      orderId: json['orderId'] as String?,
      user: json['user'] is Map<String, dynamic>
          ? ReviewUser.fromJson(json['user'] as Map<String, dynamic>)
          : ReviewUser(id: ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rating': rating,
      'comment': comment,
      'userId': userId,
      'restaurantId': restaurantId,
      'orderId': orderId,
      'user': user.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ReviewUser {
  final String id;
  final String? nom;
  final String? imageUrl;

  ReviewUser({
    required this.id,
    this.nom,
    this.imageUrl,
  });

  factory ReviewUser.fromJson(Map<String, dynamic> json) {
    return ReviewUser(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'imageUrl': imageUrl,
    };
  }
}

class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    // Un restaurant sans avis peut renvoyer des champs null/absents → tout
    // doit retomber sur des valeurs par défaut sans crasher.
    final distribution =
        (json['ratingDistribution'] as Map<String, dynamic>?) ?? const {};
    return ReviewStats(
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      ratingDistribution: {
        1: (distribution['1'] as num?)?.toInt() ?? 0,
        2: (distribution['2'] as num?)?.toInt() ?? 0,
        3: (distribution['3'] as num?)?.toInt() ?? 0,
        4: (distribution['4'] as num?)?.toInt() ?? 0,
        5: (distribution['5'] as num?)?.toInt() ?? 0,
      },
    );
  }
}

class CanReviewResponse {
  final bool canReview;
  final String? reason;
  final String? existingReviewId;

  CanReviewResponse({
    required this.canReview,
    this.reason,
    this.existingReviewId,
  });

  factory CanReviewResponse.fromJson(Map<String, dynamic> json) {
    return CanReviewResponse(
      canReview: json['canReview'] as bool? ?? false,
      reason: json['reason'] as String?,
      existingReviewId: json['existingReviewId'] as String?,
    );
  }
}
