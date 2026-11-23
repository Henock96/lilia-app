// Feuille « opérateur + numéro » demandée au moment de payer.
//
// Le choix de l'opérateur a quitté l'écran « Confirmer la commande » : il se
// fait désormais ici, juste avant `POST /payments`, au checkout (parcours
// `PAY_FIRST`) comme depuis la fiche commande (`ACCEPT_FIRST`, reprise). Une
// seule feuille pour les deux chemins.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/payments/presentation/payment_choice_sheet.dart';
import 'package:lilia_app/utils/currency.dart';

bool _numeroValide(String input) =>
    RegExp(r'^0[456]\d{7}$').hasMatch(input.replaceAll(' ', ''));

/// Monte un bouton qui ouvre la feuille et range son résultat dans [sortie].
Future<void> _ouvrir(
  WidgetTester tester, {
  required List<PaymentChoice?> sortie,
  String initialMethod = 'MTN_MOMO',
  String initialPhone = '',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              sortie.add(
                await showPaymentChoiceSheet(
                  context,
                  amount: 3225,
                  initialMethod: initialMethod,
                  initialPhone: initialPhone,
                  isValidPhone: _numeroValide,
                ),
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('annonce le montant et rend le numéro pré-rempli', (
    tester,
  ) async {
    final sortie = <PaymentChoice?>[];
    await _ouvrir(tester, sortie: sortie, initialPhone: '06 345 67 89');

    expect(find.textContaining(formatPrice(3225)), findsOneWidget);

    await tester.tap(find.text('Envoyer la demande de paiement'));
    await tester.pumpAndSettle();

    expect(sortie.single, (phone: '06 345 67 89', method: 'MTN_MOMO'));
  });

  testWidgets('le client peut choisir Airtel', (tester) async {
    final sortie = <PaymentChoice?>[];
    await _ouvrir(tester, sortie: sortie, initialPhone: '05 345 67 89');

    await tester.tap(find.text('Airtel Money'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer la demande de paiement'));
    await tester.pumpAndSettle();

    expect(sortie.single?.method, 'AIRTEL_MONEY');
  });

  testWidgets('sans numéro, rien ne part', (tester) async {
    final sortie = <PaymentChoice?>[];
    await _ouvrir(tester, sortie: sortie);

    await tester.tap(find.text('Envoyer la demande de paiement'));
    await tester.pumpAndSettle();

    expect(find.text('Numéro requis'), findsOneWidget);
    expect(sortie, isEmpty, reason: 'la feuille reste ouverte');
  });

  testWidgets('numéro non congolais refusé', (tester) async {
    final sortie = <PaymentChoice?>[];
    await _ouvrir(tester, sortie: sortie, initialPhone: '123');

    await tester.tap(find.text('Envoyer la demande de paiement'));
    await tester.pumpAndSettle();

    expect(find.text('Numéro congolais invalide'), findsOneWidget);
    expect(sortie, isEmpty);
  });

  testWidgets('fermée sans choix : null', (tester) async {
    final sortie = <PaymentChoice?>[];
    await _ouvrir(tester, sortie: sortie, initialPhone: '06 345 67 89');

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(sortie, [null]);
  });
}
