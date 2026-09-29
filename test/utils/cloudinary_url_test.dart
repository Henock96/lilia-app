import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/utils/cloudinary_url.dart';

const _base = 'https://res.cloudinary.com/lilia/image/upload/';

void main() {
  test('URL Cloudinary brute : redimensionnée au palier, sans agrandir', () {
    expect(
      cloudinarySized('${_base}v1712/produits/poulet.jpg', 300),
      '${_base}w_480,c_limit,q_auto/v1712/produits/poulet.jpg',
    );
  });

  test('paliers : même variante pour des largeurs voisines', () {
    expect(cloudinaryWidthStep(200), 240);
    expect(cloudinaryWidthStep(241), 480);
    expect(cloudinaryWidthStep(1170), 1600);
    expect(cloudinaryWidthStep(5000), 1600);
  });

  test('pas de f_auto (AVIF illisible par Flutter)', () {
    expect(cloudinarySized('${_base}v1/a.jpg', 300), isNot(contains('f_auto')));
  });

  test('URL déjà transformée : inchangée', () {
    const u = '${_base}w_800,c_fill/v1/a.jpg';
    expect(cloudinarySized(u, 300), u);
  });

  test('URL sans version : réécrite', () {
    expect(
      cloudinarySized('${_base}produits/a.png', 100),
      '${_base}w_240,c_limit,q_auto/produits/a.png',
    );
  });

  test('autres hôtes, vidéos, largeur inconnue : inchangées', () {
    for (final u in [
      'https://example.com/a.jpg',
      'https://res.cloudinary.com/lilia/video/upload/v1/a.mp4',
    ]) {
      expect(cloudinarySized(u, 300), u);
    }
    expect(
      cloudinarySized('${_base}v1/a.jpg', double.infinity),
      '${_base}v1/a.jpg',
    );
    expect(cloudinarySized('${_base}v1/a.jpg', 0), '${_base}v1/a.jpg');
  });

  testWidgets('AppCachedImage demande la variante à la taille affichée', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(390, 844), devicePixelRatio: 3),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppCachedImage(
            imageUrl: '${_base}v1/a.jpg',
            width: 160,
            height: 110,
          ),
        ),
      ),
    );
    final img = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    // 160 dp × 3 = 480 px.
    expect(img.imageUrl, '${_base}w_480,c_limit,q_auto/v1/a.jpg');
  });
}
