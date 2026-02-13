class AppBanner {
  final String id;
  final String title;
  final String imageUrl;
  final String? description;
  final String? linkUrl;
  final bool isActive;
  final int displayOrder;
  final String? restaurantId;

  AppBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.description,
    this.linkUrl,
    this.isActive = true,
    this.displayOrder = 0,
    this.restaurantId,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      id: json['id'] as String,
      title: json['title'] as String,
      imageUrl: json['imageUrl'] as String,
      description: json['description'] as String?,
      linkUrl: json['linkUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      displayOrder: json['displayOrder'] as int? ?? 0,
      restaurantId: json['restaurantId'] as String?,
    );
  }
}
