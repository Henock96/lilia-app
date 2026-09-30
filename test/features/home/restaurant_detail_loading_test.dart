// P3-14 — la fiche vendeur n'est plus anonyme ni sans issue pendant son
// chargement : le nom connu de l'écran d'origine s'affiche avec un retour,
// et rien n'est inventé quand l'écran s'ouvre par un lien profond.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/presentation/restaurant_detail_screen.dart';
import 'package:lilia_app/models/restaurant.dart';

const _id = 'r1';

Future<void> _pump(
  WidgetTester tester, {
  String? name,
  required Future<Restaurant> Function() load,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // Sans relance automatique : l'erreur doit s'afficher, pas être
      // rejouée en boucle derrière le squelette.
      retry: (_, _) => null,
      overrides: [
        restaurantControllerProvider(_id).overrideWith((ref) => load()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RestaurantDetailScreen(
                      restaurantId: _id,
                      restaurantName: name,
                    ),
                  ),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  // Pas de `pumpAndSettle` : le squelette de chargement anime en boucle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('chargement : le nom transmis et un retour sont visibles', (
    tester,
  ) async {
    final never = Completer<Restaurant>();
    await _pump(tester, name: 'Chez Mama Ngalula', load: () => never.future);

    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Chez Mama Ngalula'),
      ),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ouvrir'), findsOneWidget);
  });

  testWidgets('lien profond sans nom : retour, aucun nom inventé', (
    tester,
  ) async {
    final never = Completer<Restaurant>();
    await _pump(tester, load: () => never.future);

    expect(find.byType(BackButton), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isNull);
    expect(find.text('Votre Restaurant'), findsNothing);
  });

  testWidgets('erreur : message lisible, réessayer et retour', (tester) async {
    await _pump(
      tester,
      name: 'Chez Mama Ngalula',
      load: () async =>
          throw const ApiException('Boutique introuvable', statusCode: 404),
    );
    await tester.pump();

    expect(find.text('Impossible de charger'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Chez Mama Ngalula'), findsOneWidget);
  });
}
