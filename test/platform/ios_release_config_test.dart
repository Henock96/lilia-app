// La configuration iOS qui décide si un push arrive — **vérifiée par un test.**
//
// Ces valeurs ne se voient pas à l'exécution : une application compilée avec
// `aps-environment: development` et distribuée par TestFlight obtient un jeton
// APNS bac à sable, Apple refuse la livraison, et **rien** dans l'application
// ne l'indique. C'est ce qui s'est produit : le fichier Release était une
// copie du fichier Debug, valeur comprise.
//
// Un fichier de configuration qu'aucun test ne lit est un fichier qui dérive.
// Même motif que `app_version_matches_pubspec_test.dart`.
//
// ⚠️ Ces tests couvrent le CODE du dépôt. Ils ne peuvent rien dire du profil
// de provisioning, de la clé APNs de la console Firebase, ni du certificat de
// distribution — voir la section « Actions manuelles » du rapport.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lecture volontairement naïve : ces fichiers sont des plists XML à plat,
/// et dépendre d'un analyseur complet pour lire quatre clés serait une
/// dépendance de plus pour un test qui doit rester évident à relire.
String _lire(String chemin) => File(chemin).readAsStringSync();

/// Valeur d'une clé `<key>k</key><string>v</string>`, espaces et retours à la
/// ligne tolérés.
String? _valeurTexte(String plist, String cle) {
  final motif = RegExp(
    '<key>${RegExp.escape(cle)}</key>\\s*<string>([^<]*)</string>',
  );
  return motif.firstMatch(plist)?.group(1);
}

/// Entrées d'un `<array>` de chaînes associé à une clé.
List<String> _valeursTableau(String plist, String cle) {
  final bloc = RegExp(
    '<key>${RegExp.escape(cle)}</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist)?.group(1);
  if (bloc == null) return const [];
  return RegExp('<string>([^<]*)</string>')
      .allMatches(bloc)
      .map((m) => m.group(1)!)
      .toList();
}

void main() {
  group('APNs — l’environnement de chaque configuration', () {
    test('Release déclare `production`', () {
      final release = _lire('ios/Runner/RunnerRelease.entitlements');

      expect(
        _valeurTexte(release, 'aps-environment'),
        'production',
        reason:
            'avec `development`, soit la signature échoue contre un profil de '
            'distribution, soit le binaire obtient un jeton APNS bac à sable '
            'et AUCUN push n’arrive en TestFlight ni sur l’App Store',
      );
    });

    test('Debug/Profile déclare `development`', () {
      final debug = _lire('ios/Runner/Runner.entitlements');

      expect(
        _valeurTexte(debug, 'aps-environment'),
        'development',
        reason:
            '`flutter run` compile en Debug ; sans cet entitlement, '
            '`getAPNSToken()` reste nul et `getToken()` lève '
            '`apns-token-not-set` même sur un iPhone physique',
      );
    });

    test('les deux fichiers existent et ne sont pas identiques', () {
      final debug = _lire('ios/Runner/Runner.entitlements');
      final release = _lire('ios/Runner/RunnerRelease.entitlements');

      expect(
        _valeurTexte(debug, 'aps-environment'),
        isNot(_valeurTexte(release, 'aps-environment')),
        reason:
            'leur seule raison d’être est de différer sur cette clé ; une '
            'copie de l’un sur l’autre est le défaut d’origine',
      );
    });

    test('le projet Xcode branche bien le fichier Release', () {
      final projet = _lire('ios/Runner.xcodeproj/project.pbxproj');

      expect(
        projet,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;'),
        reason: 'corriger le fichier ne sert à rien s’il n’est pas référencé',
      );
    });
  });

  group('Info.plist — permissions et modes d’arrière-plan', () {
    late String plist;
    setUp(() => plist = _lire('ios/Runner/Info.plist'));

    test('aucun mode d’arrière-plan qui ne soit utilisé', () {
      final modes = _valeursTableau(plist, 'UIBackgroundModes');

      expect(modes, contains('remote-notification'));
      expect(
        modes,
        isNot(contains('location')),
        reason:
            'la géolocalisation ne sert qu’au sélecteur d’adresse, au premier '
            'plan, par un `getCurrentPosition()` ponctuel — aucun '
            '`getPositionStream` n’existe dans lib/. Déclarer ce mode est un '
            'motif de rejet App Store (2.5.4)',
      );
      expect(
        modes,
        isNot(contains('fetch')),
        reason:
            'aucun BGAppRefreshTask ni setMinimumBackgroundFetchInterval dans '
            'AppDelegate.swift',
      );
    });

    test('la chaîne d’usage de la localisation « quand utilisée » est là', () {
      expect(
        _valeurTexte(plist, 'NSLocationWhenInUseUsageDescription'),
        isNotNull,
        reason: 'le sélecteur d’adresse demande la position au premier plan',
      );
    });

    // La chaîne « Always » est **requise** par App Store Connect
    // (avertissement ITMS-90683) : le binaire de `geolocator_apple` référence
    // `requestAlwaysAuthorization`, même si l'app ne l'appelle jamais — le
    // plugin demande « quand utilisée » dès que cette clé-là existe. Son
    // interrupteur `BYPASS_PERMISSION_LOCATION_ALWAYS` ne s'applique pas : le
    // plugin est compilé par Swift Package Manager, pas par le Podfile.
    //
    // Ce qui reste interdit, c'est de **décrire** un usage en arrière-plan qui
    // n'existe pas (et le mode `location`, vérifié plus haut).
    test(
      'chaîne « Always » présente, sans promettre d’usage en arrière-plan',
      () {
        final always = _valeurTexte(
          plist,
          'NSLocationAlwaysAndWhenInUseUsageDescription',
        );
        expect(always, isNotNull, reason: 'avertissement ITMS-90683 d’Apple');
        expect(
          always!.toLowerCase(),
          isNot(contains('arrière-plan')),
          reason:
              'aucun suivi de position hors premier plan : le dire serait faux '
              'et appellerait une question du relecteur (2.5.4)',
        );
      },
    );
  });

  group('cohérence du bundle identifier', () {
    test('projet Xcode, GoogleService-Info et firebase_options s’accordent', () {
      const attendu = 'com.dreesis.lilia.liliaApp';

      expect(
        _lire('ios/Runner.xcodeproj/project.pbxproj'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = $attendu;'),
      );
      expect(
        _valeurTexte(_lire('ios/Runner/GoogleService-Info.plist'), 'BUNDLE_ID'),
        attendu,
      );
      expect(
        _lire('lib/firebase_options.dart'),
        contains("iosBundleId: '$attendu'"),
        reason:
            'un bundle divergent crée une application iOS distincte côté '
            'Firebase : nouvelle installation, session perdue, et des push '
            'envoyés à un projet qui n’est pas celui installé',
      );
    });
  });
}
