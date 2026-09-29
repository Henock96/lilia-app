// P3-02 — puces du filtre vendeur à 2× : le texte tient **dans** la puce.
//
// Un `Row` ne signale pas le débordement sur l'axe transversal : fixée à
// 40 px, la barre rognait le texte sans lever d'erreur. On compare donc les
// rectangles.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/presentation/widgets/vendor_type_filter_bar.dart';
import 'package:lilia_app/theme/app_theme.dart';

import '../helpers/real_fonts.dart';

void main() {
  setUpAll(chargerPolicesReelles);

  for (final echelle in [1.0, 1.5, 2.0]) {
    testWidgets('« Tous » entier dans sa puce à $echelle×', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 780),
                textScaler: TextScaler.linear(echelle),
              ),
              child: const Scaffold(body: VendorTypeFilterBar()),
            ),
          ),
        ),
      );
      final texte = tester.getRect(find.text('Tous'));
      final puce = tester.getRect(
        find
            .ancestor(of: find.text('Tous'), matching: find.byType(Material))
            .first,
      );
      expect(texte.top, greaterThanOrEqualTo(puce.top));
      expect(texte.bottom, lessThanOrEqualTo(puce.bottom));
      // Le texte reçoit au moins la hauteur de son corps. À 40 px fixes, la
      // ligne était plafonnée à 24 px pour un corps de 26 px à 2× : lettres
      // coupées, sans aucune erreur de rendu.
      expect(texte.height, greaterThanOrEqualTo(13 * echelle));
    });
  }
}
