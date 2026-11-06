// « Les boutiques sont fermées » est un verdict : il ne se prononce pas sans la
// liste des boutiques.
//
// Audit du 05/11/2026 : `value ?? const []` traitait une liste absente comme
// une liste vide. Pendant un chargement ou une panne, l'accueil annonçait des
// boutiques fermées alors que personne n'en savait rien.
//
// La panne elle-même se dit ailleurs, une seule fois : voir
// `home_screen_states_test.dart`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/presentation/widgets/available_now_section.dart';
import 'package:lilia_app/models/restaurant.dart';

final _fermees = find.text('Les boutiques sont fermées pour le moment.');

Future<void> _ouvrir(
  WidgetTester tester,
  Future<List<RestaurantSummary>> Function() lecture,
) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [vendorsListProvider.overrideWith((ref) => lecture())],
      child: const MaterialApp(home: Scaffold(body: ReopeningSoon())),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('liste en échec : aucun verdict', (tester) async {
    await _ouvrir(
      tester,
      () async => throw const ApiException('panne', statusCode: 500),
    );

    expect(_fermees, findsNothing);
  });

  testWidgets('pendant le chargement : aucun verdict', (tester) async {
    await _ouvrir(tester, () => Completer<List<RestaurantSummary>>().future);

    expect(_fermees, findsNothing);
  });

  testWidgets('liste chargée et vide : le verdict reste', (tester) async {
    await _ouvrir(tester, () async => const []);

    expect(_fermees, findsOneWidget);
  });
}
