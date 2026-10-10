// C-32 — audit du 09/10/2026 : quartiers en erreur sans bouton de réessai.
// Le provider est `keepAlive` : sans geste explicite, l'erreur restait
// affichée jusqu'au redémarrage, et le quartier est obligatoire.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/address/presentation/pages/address_page.dart';
import 'package:lilia_app/features/quartiers/application/quartiers_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/quartier.dart';

class _Adresses extends AdresseController {
  @override
  Future<List<Adresse>> build() async => const [];
}

void main() {
  testWidgets('« Réessayer » relance la lecture des quartiers', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    var lectures = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          adresseControllerProvider.overrideWith(_Adresses.new),
          quartiersListProvider.overrideWith((ref) async {
            lectures++;
            if (lectures == 1) throw Exception('réseau');
            return [Quartier(id: 'q-1', nom: 'Poto-Poto', ville: 'Brazzaville')];
          }),
        ],
        child: const MaterialApp(home: AddressPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(FloatingActionButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Quartiers indisponibles.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quartiers_retry')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(lectures, 2);
    expect(find.text('Quartiers indisponibles.'), findsNothing);
  });
}
