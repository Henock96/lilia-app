// La carte fidélité doit se comprendre seule : solde, valeur, seuil, comment
// gagner, comment utiliser — sans page d'aide, et lisible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/presentation/widgets/loyalty_card.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:lilia_app/utils/currency.dart';

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

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('contraste AA — ${theme.brightness.name}', (tester) async {
      await _monter(tester, points: 2, theme: theme);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
