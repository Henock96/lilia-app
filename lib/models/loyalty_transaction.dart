class LoyaltyTransaction {
  final String id;
  final int points;
  final String reason;
  final String? orderId;
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.points,
    required this.reason,
    this.orderId,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'],
      points: (json['points'] as num).toInt(),
      reason: json['reason'],
      orderId: json['orderId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class ReferralStats {
  final String referralCode;
  final int totalReferrals;
  final int rewardedReferrals;
  final int loyaltyPoints;

  ReferralStats({
    required this.referralCode,
    required this.totalReferrals,
    required this.rewardedReferrals,
    required this.loyaltyPoints,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      referralCode: json['referralCode'] ?? '',
      totalReferrals: (json['totalReferrals'] as num?)?.toInt() ?? 0,
      rewardedReferrals: (json['rewardedReferrals'] as num?)?.toInt() ?? 0,
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }
}
