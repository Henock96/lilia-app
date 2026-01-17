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
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      userId: json['userId'] as String,
      restaurantId: json['restaurantId'] as String,
      orderId: json['orderId'] as String?,
      user: ReviewUser.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
      id: json['id'] as String,
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
    final distribution = json['ratingDistribution'] as Map<String, dynamic>;
    return ReviewStats(
      averageRating: (json['averageRating'] as num).toDouble(),
      totalReviews: json['totalReviews'] as int,
      ratingDistribution: {
        1: distribution['1'] as int? ?? 0,
        2: distribution['2'] as int? ?? 0,
        3: distribution['3'] as int? ?? 0,
        4: distribution['4'] as int? ?? 0,
        5: distribution['5'] as int? ?? 0,
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
      canReview: json['canReview'] as bool,
      reason: json['reason'] as String?,
      existingReviewId: json['existingReviewId'] as String?,
    );
  }
}
