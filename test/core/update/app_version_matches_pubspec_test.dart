import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/update/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// La version comparée au seuil de mise à jour est celle du **binaire**.
///
/// ## Ce que ce test gardait, et pourquoi il a changé (UPD-001)
///
/// Il vérifiait qu'une constante `AppVersion.current` recopiait
/// `pubspec.yaml`. Le 22/09/2026 il échouait (pubspec `1.3.1+35`, constante
/// `1.3.0+34`) — sans que rien ne l'exécute avant une release. Publié ainsi, le
/// binaire 1.3.1 se serait déclaré 1.3.0+34 : un `minAppVersion = 1.3.1`
/// aurait renvoyé au store, à vie, ceux qui venaient de mettre à jour.
///
/// La constante a disparu : `AppVersion.installed()` lit ce que Flutter a
/// compilé depuis le pubspec. Ce qui reste à garder :
///
/// 1. la version du pubspec est lisible par `AppVersion` — sinon le binaire
///    se déclarerait « version inconnue » et échapperait à tout seuil ;
/// 2. ce que la plateforme rapporte pour ce pubspec redonne exactement cette
///    version ;
/// 3. personne ne réintroduit une copie écrite à la main.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String pubspecVersion() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'Aucune ligne `version:` dans pubspec.yaml.');
    return match!.group(1)!;
  }

  setUp(AppVersion.resetInstalledForTest);

  test('la version du pubspec est lisible par AppVersion', () {
    final declared = pubspecVersion();
    expect(
      AppVersion.tryParse(declared),
      isNotNull,
      reason:
          'pubspec.yaml déclare « $declared », illisible par AppVersion '
          '(format attendu major.minor.patch+build). Le binaire se déclarerait '
          'de version inconnue et échapperait au seuil minAppVersion.',
    );
  });

  test('la version installée est celle que la plateforme rapporte pour ce pubspec', () async {
    final declared = pubspecVersion();
    final [name, build] = declared.split('+');
    PackageInfo.setMockInitialValues(
      appName: 'Lilia Food',
      packageName: 'com.dreesis.lilia.lilia_app',
      version: name,
      buildNumber: build,
      buildSignature: '',
    );

    expect(await AppVersion.installed(), AppVersion.parse(declared));
  });

  test('buildNumber vide : version lue sans build', () {
    expect(
      AppVersion.fromPlatform(version: '1.3.1', buildNumber: ''),
      AppVersion.parse('1.3.1'),
    );
  });

  test('version illisible : null, jamais une valeur inventée', () {
    expect(AppVersion.fromPlatform(version: '1.3', buildNumber: '35'), isNull);
    expect(
      AppVersion.fromPlatform(version: '1.3.1-beta', buildNumber: '35'),
      isNull,
    );
  });

  test('aucune version écrite en dur dans le code de mise à jour', () {
    final source = File('lib/core/update/app_version.dart').readAsStringSync();
    expect(
      RegExp(r'^\s*static\s+const\s+current\b', multiLine: true).hasMatch(source),
      isFalse,
      reason:
          'Une constante de version recopiée du pubspec a déjà divergé une '
          'fois (UPD-001). La version vient de package_info_plus.',
    );
  });
}
