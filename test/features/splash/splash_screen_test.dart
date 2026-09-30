import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/splash/presentation/splash_screen.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

import '../../theme/contrast_test.dart' show contrastRatio;

/// Écran de démarrage (UI Refresh, C5) : continuité avec le natif, roue
/// différée, aucune décision de sortie.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          platformBrightness: brightness,
          disableAnimations: disableAnimations,
        ),
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
  }

  testWidgets('aucune roue à la première frame ni avant 800 ms', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('la roue apparaît après 800 ms, annoncée', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Chargement en cours'), findsOneWidget);
  });

  testWidgets('réduire les animations : la roue apparaît sans fondu', (
    tester,
  ) async {
    await pump(tester, disableAnimations: true);
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('le logo est celui du natif, à la même taille, annoncé', (
    tester,
  ) async {
    await pump(tester);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/branding/logo_mark_white.png',
    );
    expect(image.width, SplashScreen.splashLogoWidth);
    expect(find.bySemanticsLabel('Lilia Food'), findsOneWidget);
  });

  testWidgets('le fond suit la luminosité du système, comme le natif', (
    tester,
  ) async {
    await pump(tester);
    Color fond() =>
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;
    expect(fond(), LiliaColors.orange600);

    await pump(tester, brightness: Brightness.dark);
    expect(fond(), LiliaColors.orange700);
  });

  test('le blanc est lisible sur les deux fonds', () {
    expect(
      contrastRatio(
        Colors.white,
        SplashScreen.splashBackground(Brightness.light),
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(
        Colors.white,
        SplashScreen.splashBackground(Brightness.dark),
      ),
      greaterThanOrEqualTo(7),
    );
  });

  test('les couleurs natives sont celles des jetons', () {
    String hex(Color c) =>
        c.toARGB32().toRadixString(16).substring(2).toUpperCase();
    final light = hex(LiliaColors.orange600);
    final dark = hex(LiliaColors.orange700);
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains('#$light'),
    );
    expect(
      File(
        'android/app/src/main/res/values-night/colors.xml',
      ).readAsStringSync(),
      contains('#$dark'),
    );
    final ios = File(
      'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
    ).readAsStringSync();
    expect(ios, contains('"red" : "0x${light.substring(0, 2)}"'));
    expect(ios, contains('"red" : "0x${dark.substring(0, 2)}"'));
    for (final v31 in ['values-v31', 'values-night-v31']) {
      final styles = File(
        'android/app/src/main/res/$v31/styles.xml',
      ).readAsStringSync();
      expect(styles, contains('windowSplashScreenBackground'));
      expect(styles, contains('@drawable/android12_splash_logo'));
    }
    expect(
      File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync(),
      contains('name="LaunchBackground"'),
    );
  });

  test('le logo du splash pèse au plus 30 Ko', () {
    expect(
      File('assets/branding/logo_mark_white.png').lengthSync(),
      lessThanOrEqualTo(30 * 1024),
    );
  });
}
