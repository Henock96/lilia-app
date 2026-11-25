// Fonctionnalités matérielles — **vérifiées par un test** (24/11/2026).
//
// `android:screenOrientation="portrait"` fait déduire au Play Store une
// exigence implicite `android.hardware.screen.portrait` obligatoire : la
// console refuse l'envoi pour examen (« les déclarations de fonctionnalités
// matérielles requises limitent la disponibilité ») et les appareils qui ne
// déclarent pas d'écran portrait (tablettes, Chromebooks, Android XR) ne
// peuvent pas installer l'app. L'app reste verrouillée en portrait ; seule
// l'exigence devient facultative.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';

void main() {
  final manifest = File(_manifest).readAsStringSync();

  test('l’écran reste verrouillé en portrait', () {
    expect(manifest, contains('android:screenOrientation="portrait"'));
  });

  test('l’écran portrait est déclaré facultatif', () {
    expect(
      manifest,
      matches(
        RegExp(
          r'<uses-feature\s+android:name="android\.hardware\.screen\.portrait"'
          r'\s+android:required="false"\s*/>',
        ),
      ),
    );
  });

  test('aucune fonctionnalité matérielle n’est déclarée obligatoire', () {
    final obligatoires = RegExp(r'<uses-feature[^>]*>')
        .allMatches(manifest)
        .map((m) => m.group(0)!)
        .where((tag) => !tag.contains('android:required="false"'));
    expect(obligatoires, isEmpty);
  });
}
