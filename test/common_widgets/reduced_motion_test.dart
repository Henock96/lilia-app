// P3-26 — « Réduire les animations » : aucune entrée animée.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';

Future<void> _monter(WidgetTester tester, {required bool reduire}) =>
    tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduire),
          child: Column(
            children: [
              const Text('a').fadeSlideIn(),
              const Text('b').fadeScaleIn(),
              const Text('c').staggeredIn(3),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('animations réduites : rendu direct, aucun Animate', (
    tester,
  ) async {
    await _monter(tester, reduire: true);
    expect(find.byType(Animate), findsNothing);
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('par défaut : entrées animées', (tester) async {
    await _monter(tester, reduire: false);
    expect(find.byType(Animate), findsNWidgets(3));
    await tester.pumpAndSettle();
  });
}
