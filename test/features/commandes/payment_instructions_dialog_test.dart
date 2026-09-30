// La modale d'instructions, extraite du checkout : elle affiche ce que le
// serveur a fixé (numéro, montant, référence) et rend les gestes à la page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/payment_instructions_dialog.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:lilia_app/utils/currency.dart';

void main() {
  var plusTard = 0;
  var paye = 0;

  Future<void> monter(
    WidgetTester tester, {
    bool isMtn = true,
    ThemeData? theme,
  }) {
    plusTard = 0;
    paye = 0;
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: PaymentInstructionsDialog(
            isMtn: isMtn,
            methodLabel: isMtn ? 'MTN Mobile Money' : 'Airtel Money',
            paymentPhoneNumber: '+242 06 000 00 00',
            amountDue: 24000,
            reference: 'LIL-7Q2K',
            onLater: () => plusTard++,
            onPaid: () => paye++,
          ),
        ),
      ),
    );
  }

  testWidgets('affiche numéro, montant et référence du serveur', (
    tester,
  ) async {
    await monter(tester);
    expect(find.text('+242 06 000 00 00'), findsOneWidget);
    expect(find.text(formatPrice(24000)), findsOneWidget);
    expect(find.text('LIL-7Q2K'), findsOneWidget);
    expect(find.text('1. Composez *105#'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Montant à envoyer : ${formatPrice(24000)}'),
      findsOneWidget,
    );
  });

  testWidgets('Airtel : ses propres étapes', (tester) async {
    await monter(tester, isMtn: false);
    expect(find.text('1. Composez *555#'), findsOneWidget);
    expect(find.textContaining('*105#'), findsNothing);
  });

  testWidgets('les gestes reviennent à la page', (tester) async {
    await monter(tester);
    await tester.tap(find.text('Plus tard'));
    await tester.tap(find.text('J\'ai payé'));
    expect((plusTard, paye), (1, 1));
  });

  testWidgets('contraste AA, clair et sombre', (tester) async {
    // Téléphone haut (390 × 1000) : dans la surface par défaut (800 × 600),
    // la dernière ligne de la modale défilante était coupée, et la règle de
    // contraste échantillonnait alors le fond sous le texte (1.21:1 mesuré en
    // CI, avec les polices embarquées). Ce n'est pas ce qu'on veut mesurer.
    tester.view.physicalSize = const Size(390 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await monter(tester, theme: theme);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    }
  });
}
