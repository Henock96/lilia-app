/// Redimensionnement à la volée des images Cloudinary (P3-21).
///
/// L'app téléchargeait les originaux : jusqu'à 1200 × 800 px pour une carte de
/// 150 px de haut. Mesuré le 29/09 sur les 11 images « populaires » de la
/// production : 755 Ko en original, 332 Ko redimensionnées (−56 %).
///
/// Règles :
/// - seules les URL `res.cloudinary.com/…/image/upload/…` **sans**
///   transformation existante sont réécrites ; toute autre URL passe telle
///   quelle ;
/// - `c_limit` : réduit, n'agrandit jamais une image déjà petite ;
/// - `q_auto` : compression adaptée par Cloudinary ; **pas** de `f_auto`,
///   qui peut servir de l'AVIF que le décodeur de Flutter ne lit pas ;
/// - largeur arrondie au palier supérieur ([kCloudinaryWidthSteps]) pour que
///   toutes les cartes demandent la même variante — une URL différente par
///   appareil ruinerait le cache du CDN et le cache disque.
library;

const kCloudinaryWidthSteps = <int>[240, 480, 720, 1080, 1600];

final _upload = RegExp(
  r'^(https?://res\.cloudinary\.com/[^/]+/image/upload/)(.+)$',
);

/// Palier de largeur (px physiques) pour [physicalWidth].
int cloudinaryWidthStep(double physicalWidth) {
  for (final step in kCloudinaryWidthSteps) {
    if (physicalWidth <= step) return step;
  }
  return kCloudinaryWidthSteps.last;
}

/// URL redimensionnée à [physicalWidth] px, ou [url] inchangée.
String cloudinarySized(String url, double physicalWidth) {
  if (!physicalWidth.isFinite || physicalWidth <= 0) return url;
  final m = _upload.firstMatch(url);
  if (m == null) return url;
  final rest = m.group(2)!;
  // Déjà transformée (premier segment `w_…,c_…`) : on ne superpose rien.
  final first = rest.split('/').first;
  if (first.contains('_') && !RegExp(r'^v\d+$').hasMatch(first)) return url;
  final w = cloudinaryWidthStep(physicalWidth);
  return '${m.group(1)}w_$w,c_limit,q_auto/$rest';
}
