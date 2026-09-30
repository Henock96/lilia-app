// La carte fidélité doit se comprendre seule : solde, valeur, seuil, comment
// gagner, comment utiliser — sans page d'aide, et lisible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/presentation/widgets/loyalty_card.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';

import '../../theme/contrast_test.dart' show contrastRatio;

/// Barème de production (1 pt = 100 XAF), pas le défaut Prisma.
const _prod = PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 5,
  referrerBonusPoints: 3,
);

Future<void> _monter(
  WidgetTester tester, {
  required int points,
  PlatformSettings? settings = _prod,
  ThemeData? theme,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: LoyaltyCardView(
          points: points,
          settings: settings,
          history: const Text('historique'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('solde, valeur serveur, et comment gagner / utiliser', (
    tester,
  ) async {
    await _monter(tester, points: 12);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Soit ${formatPrice(1200)} de réduction'), findsOneWidget);
    expect(
      find.text('Utilisables dès votre prochaine commande.'),
      findsOneWidget,
    );
    expect(find.textContaining('par commande livrée'), findsOneWidget);
    expect(find.textContaining('Utiliser mes points'), findsOneWidget);
    expect(find.bySemanticsLabel('12 points de fidélité'), findsOneWidget);
  });

  testWidgets('sous le seuil : combien il manque', (tester) async {
    await _monter(tester, points: 2);
    expect(
      find.text('Encore 3 pt avant de pouvoir les utiliser (minimum 5 pt).'),
      findsOneWidget,
    );
  });

  testWidgets('barème indisponible : aucune conversion inventée', (
    tester,
  ) async {
    await _monter(tester, points: 12, settings: null);
    expect(find.text('Valeur indisponible pour le moment'), findsOneWidget);
    expect(find.textContaining('XAF'), findsNothing);
  });

  testWidgets('historique chargé seulement à la demande', (tester) async {
    await _monter(tester, points: 12);
    expect(find.text('historique'), findsNothing);
    await tester.tap(find.text('Historique'));
    await tester.pump();
    expect(find.text('historique'), findsOneWidget);
  });

  // Contraste **calculé** texte par texte contre les deux extrémités du
  // dégradé, et non `textContrastGuideline`.
  //
  // Cette règle échantillonne les pixels de la zone du texte et en garde les
  // deux couleurs dominantes. Elle ne passait que parce que les polices
  // n'étaient pas chargées : la police carrée de `flutter_test` remplissait la
  // zone de blanc. Depuis que les graisses d'Inter et d'Oswald sont
  // embarquées (Phase 3.7), les vrais glyphes, fins, sont dessinés, et la
  // règle ne voit plus que deux teintes du dégradé (« 1,11:1 ») — un faux
  // négatif sur un fond non uni, pas un défaut de contraste.
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('contraste AA — ${theme.brightness.name}', (tester) async {
      await _monter(tester, points: 2, theme: theme);
      await tester.pumpAndSettle();

      const fonds = [LiliaColors.orange600, LiliaColors.orange700];
      final textes = tester.widgetList<RichText>(
        find.descendant(
          of: find.byType(LoyaltyCardView),
          matching: find.byType(RichText),
        ),
      );
      expect(textes, isNotEmpty);
      for (final texte in textes) {
        final couleur = texte.text.style?.color;
        expect(couleur, isNotNull, reason: texte.text.toPlainText());
        for (final fond in fonds) {
          // Une couleur translucide se lit composée sur le fond.
          final vue = Color.alphaBlend(couleur!, fond);
          expect(
            contrastRatio(vue, fond),
            greaterThanOrEqualTo(4.5),
            reason: '« ${texte.text.toPlainText()} » sur $fond',
          );
        }
      }
    });
  }
}
