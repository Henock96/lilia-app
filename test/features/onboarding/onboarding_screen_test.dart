import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/page_dots.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/real_fonts.dart';
import '../../theme/contrast_test.dart' show contrastRatio;

/// Appels à `completeOnboarding` — hors du notifier : un notifier n'expose
/// rien d'autre que son `state` (`avoid_public_notifier_properties`).
int _appels = 0;

/// Onboarding photo (UI Refresh, C6).
class _Compteur extends OnboardingStatus {
  @override
  Future<bool> build() async => false;

  @override
  Future<void> completeOnboarding() async {
    _appels++;
    state = const AsyncData(true);
  }
}

void main() {
  setUpAll(chargerPolicesReelles);


  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    double textScale = 1,
    bool disableAnimations = false,
    bool vraiePersistance = false,
  }) async {
    _appels = 0;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (!vraiePersistance)
            onboardingStatusProvider.overrideWith(_Compteur.new),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: disableAnimations,
              ),
              child: const OnboardingScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PageDots dots(WidgetTester tester) =>
      tester.widget<PageDots>(find.byType(PageDots));

  testWidgets('navigation 1 → 2 → 3, puis « Commencer »', (tester) async {
    await pump(tester);
    expect(find.text('Les bonnes adresses de Brazzaville'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    expect(find.text('Commencer'), findsNothing);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Commandez en quelques gestes'), findsOneWidget);
    expect(dots(tester).index, 1);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Livré chez vous ou à emporter'), findsOneWidget);
    expect(find.text('Passer'), findsNothing);
    expect(find.text('Suivant'), findsNothing);

    await tester.tap(find.text('Commencer'));
    await tester.pump();
    expect(_appels, 1);
  });

  testWidgets('« Passer » dès la page 1 : completeOnboarding une seule fois', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Passer'));
    await tester.tap(find.text('Passer'), warnIfMissed: false);
    await tester.pump();
    expect(_appels, 1);
  });

  testWidgets('glisser change de page', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(dots(tester).index, 1);
  });

  testWidgets('persistance : même clé onboarding_completed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester, vraiePersistance: true);
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  testWidgets('réduire les animations : « Suivant » saute sans transition', (
    tester,
  ) async {
    await pump(tester, disableAnimations: true);
    await tester.tap(find.text('Suivant'));
    await tester.pump();
    // Une seule frame : la page est déjà exactement la 2e (pas de défilement
    // animé ; seule l'onde du bouton tourne encore).
    expect(dots(tester).index, 1);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
  });

  testWidgets('aucune animation en boucle : l’écran se stabilise', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('les pastilles annoncent la page', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('Page 1 sur 3'), findsOneWidget);
  });

  for (final (nom, theme) in [
    ('clair', AppTheme.light),
    ('sombre', AppTheme.dark),
  ]) {
    for (final echelle in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('texte ×$echelle, thème $nom : aucun débordement', (
        tester,
      ) async {
        await pump(tester, theme: theme, textScale: echelle);
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Suivant'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Commencer'), findsOneWidget);
      });
    }

    test('contrastes, thème $nom', () {
      final cs = theme.colorScheme;
      final fond = theme.scaffoldBackgroundColor;
      expect(
        contrastRatio(cs.onSurfaceVariant, fond),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(theme.textTheme.headlineSmall!.color!, fond),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(cs.onPrimary, cs.primary),
        greaterThanOrEqualTo(4.5),
      );
      // Pastilles : éléments graphiques, ≥ 3:1.
      expect(contrastRatio(cs.primary, fond), greaterThanOrEqualTo(3));
      expect(contrastRatio(cs.onSurfaceVariant, fond), greaterThanOrEqualTo(3));
    });
  }

  group('contenu', () {
    test('textes imposés par le plan (§7.3)', () {
      expect(onboardingPages.map((p) => (p.title, p.description)).toList(), [
        (
          'Les bonnes adresses de Brazzaville',
          'Restaurants, cuisines maison, pâtisseries : tout au même endroit.',
        ),
        ('Commandez en quelques gestes', 'Payez par MTN MoMo ou Airtel Money.'),
        (
          'Livré chez vous ou à emporter',
          "Suivez votre commande jusqu'à la remise.",
        ),
      ]);
    });

    test('aucune promesse interdite dans le fichier', () {
      final source = File(
        'lib/features/onboarding/presentation/onboarding_screen.dart',
      ).readAsStringSync().toLowerCase();
      for (final interdit in [
        'espèces',
        'especes',
        'cash',
        'à la livraison',
        'express',
        'record',
        'minutes',
      ]) {
        expect(source, isNot(contains(interdit)), reason: interdit);
      }
    });

    test('photos optimisées : présentes, WebP, ≤ 180 Ko', () {
      for (final page in onboardingPages) {
        final f = File(page.image);
        expect(f.existsSync(), isTrue, reason: page.image);
        expect(page.image, endsWith('.webp'));
        expect(f.lengthSync(), lessThanOrEqualTo(180 * 1024));
      }
    });
  });
}
