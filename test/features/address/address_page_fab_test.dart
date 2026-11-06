// Le bouton « Nouvelle adresse » déborde de son rond.
//
// Le thème impose `CircleBorder` à tous les boutons flottants, `.extended`
// compris : le libellé blanc sortait du cercle, sur un fond clair où il
// devenait illisible. Vu sur émulateur le 05/11/2026.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/address/presentation/pages/address_page.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/theme/app_theme.dart';

class _AucuneAdresse extends AdresseController {
  @override
  Future<List<Adresse>> build() async => const [];
}

void main() {
  testWidgets('le bouton « Nouvelle adresse » épouse son libellé', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adresseControllerProvider.overrideWith(_AucuneAdresse.new)],
        child: MaterialApp(theme: AppTheme.light, home: const AddressPage()),
      ),
    );
    await tester.pump();

    final bouton = tester.widget<RawMaterialButton>(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(RawMaterialButton),
      ),
    );

    expect(bouton.shape, isA<StadiumBorder>());
  });
}
