/// Image de galerie partagée par les produits (`ProductImage`), les
/// restaurants (`VendorPhoto`) et les menus (`MenuImage`) côté backend.
/// Les trois entités exposent la même forme : `{ id, url, alt?, displayOrder,
/// isCover }`. Le backend trie déjà cover d'abord puis `displayOrder` ; on
/// retrie ici par sécurité (réponses cachées, ordre non garanti, etc.).
class GalleryImage {
  final String id;
  final String url;
  final String? alt;
  final int displayOrder;
  final bool isCover;

  const GalleryImage({
    required this.id,
    required this.url,
    this.alt,
    this.displayOrder = 0,
    this.isCover = false,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      alt: json['alt'] as String?,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isCover: json['isCover'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'alt': alt,
    'displayOrder': displayOrder,
    'isCover': isCover,
  };

  /// Parse une liste JSON brute en filtrant les URLs vides, triée cover
  /// d'abord puis par `displayOrder`. Retourne une liste vide si l'entrée
  /// n'est pas une liste (champ absent côté ancienne réponse API).
  static List<GalleryImage> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final images = raw
        .whereType<Map<String, dynamic>>()
        .map(GalleryImage.fromJson)
        .where((img) => img.url.trim().isNotEmpty)
        .toList();
    images.sort((a, b) {
      if (a.isCover != b.isCover) return a.isCover ? -1 : 1;
      return a.displayOrder.compareTo(b.displayOrder);
    });
    return images;
  }
}
