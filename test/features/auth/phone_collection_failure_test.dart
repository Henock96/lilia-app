// M-03 — la feuille de saisie du numéro ne doit plus échouer en silence.
//
// Le défaut : `_save()` appelait `updateUser`, qui rend `false` en cas
// d'échec, et se contentait de remettre `_saving` à `false`. Le client tapait
// « Enregistrer », voyait l'indicateur tourner puis s'arrêter — **et rien ne
// se passait**. Ni message, ni fermeture, ni explication. Sur la 4G de
// Brazzaville, c'est le cas le plus fréquent, pas le cas limite.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/presentation/phone_collection_sheet.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required String? echec,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(() => _FakeProfile(echec)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PhoneCollectionSheet()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> saisirEtEnregistrer(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('phone_collection_field')),
      '060000000',
    );
    await tester.tap(find.byKey(const Key('phone_collection_save')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('échec réseau → message affiché, feuille toujours ouverte',
      (tester) async {
    await pumpSheet(
      tester,
      echec: 'Connexion impossible. Vérifiez votre réseau puis réessayez.',
    );

    await saisirEtEnregistrer(tester);

    expect(find.textContaining('réseau'), findsOneWidget);
    expect(
      find.byKey(const Key('phone_collection_save')),
      findsOneWidget,
      reason: 'la feuille doit rester ouverte pour permettre de réessayer',
    );
  });

  testWidgets('échec API → message du serveur, jamais l’objet technique',
      (tester) async {
    await pumpSheet(
      tester,
      echec: 'Ce numéro est déjà utilisé.',
    );

    await saisirEtEnregistrer(tester);

    expect(find.text('Ce numéro est déjà utilisé.'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('après un échec, le bouton redevient utilisable', (tester) async {
    await pumpSheet(
      tester,
      echec: 'Connexion impossible. Vérifiez votre réseau puis réessayez.',
    );

    await saisirEtEnregistrer(tester);

    final bouton = tester.widget<FilledButton>(
      find.byKey(const Key('phone_collection_save')),
    );
    expect(bouton.onPressed, isNotNull);
  });

  testWidgets('succès → la feuille se ferme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(() => _FakeProfile(null)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const PhoneCollectionSheet(),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await saisirEtEnregistrer(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PhoneCollectionSheet), findsNothing);
  });
}

class _FakeProfile extends ProfileController {
  _FakeProfile(this._echec);

  /// `null` = succès. Sinon, le message que le vrai contrôleur rendrait.
  final String? _echec;

  @override
  FutureOr<void> build() {}

  @override
  Future<String?> updateUser(Map<String, dynamic> data) async => _echec;
}
