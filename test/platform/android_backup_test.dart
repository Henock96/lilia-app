// Sauvegarde Android — **vérifiée par un test** (SEC-09, audit du 06/11/2026).
//
// Sans réglage, Android sauvegarde les données de l'application dans le cloud
// et les recopie lors d'un transfert vers un nouveau téléphone : session
// Firebase, brouillons de commande et historique des notifications partaient
// avec. Un manifeste qu'aucun test ne lit est un manifeste qui dérive (même
// motif que `ios_release_config_test.dart`).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _rules = 'android/app/src/main/res/xml/data_extraction_rules.xml';

/// Domaines de données d'une application, au sens des règles d'extraction.
const _domains = ['root', 'file', 'database', 'sharedpref', 'external'];

String? _attribute(String xml, String name) =>
    RegExp('android:$name="([^"]*)"').firstMatch(xml)?.group(1);

void main() {
  final manifest = File(_manifest).readAsStringSync();

  test('la sauvegarde cloud est désactivée (Android 11 et avant : transfert compris)', () {
    expect(_attribute(manifest, 'allowBackup'), 'false');
  });

  test('Android 12+ : des règles d’extraction sont déclarées', () {
    // Depuis Android 12, `allowBackup="false"` ne couvre plus le transfert
    // d'appareil à appareil : seules ces règles l'excluent.
    expect(
      _attribute(manifest, 'dataExtractionRules'),
      '@xml/data_extraction_rules',
    );
    expect(File(_rules).existsSync(), isTrue, reason: _rules);
  });

  for (final section in ['cloud-backup', 'device-transfer']) {
    test('$section exclut toutes les données de l’application', () {
      final rules = File(_rules).readAsStringSync();
      final block = RegExp('<$section>(.*?)</$section>', dotAll: true)
          .firstMatch(rules)
          ?.group(1);
      expect(block, isNotNull, reason: 'section <$section> absente');
      expect(block, isNot(contains('<include')));
      for (final domain in _domains) {
        expect(
          block,
          matches(RegExp('<exclude\\s+domain="$domain"\\s+path="\\."\\s*/>')),
          reason: '$section : domaine $domain',
        );
      }
    });
  }
}
