// V-2 — audit du 09/10/2026 : libellé du bouton de la 404 rogné
// verticalement (hauteur fixe de 48), et faute d'accord.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/presentation/not_found_page.dart';

import '../../helpers/real_fonts.dart';

void main() {
  setUpAll(chargerPolicesReelles);

  for (final echelle in [1.0, 2.0]) {
    testWidgets('texte ×$echelle : le libellé tient dans le bouton', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(echelle)),
          child: const MaterialApp(home: NotFoundScreen()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('404 - Page non trouvée !'), findsOneWidget);
      // La boîte du texte est contrainte par le bouton : c'est son CONTENU
      // qui dépassait. On compare la hauteur du texte mis en page à celle de
      // la boîte qui l'affiche.
      final libelle = tester.renderObject<RenderParagraph>(
        find.text("Aller à la page d'accueil"),
      );
      expect(
        libelle.textSize.height,
        lessThanOrEqualTo(libelle.size.height + 0.01),
      );
    });
  }
}
