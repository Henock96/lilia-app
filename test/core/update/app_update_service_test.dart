import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';
import 'package:lilia_app/core/update/app_version.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de plateforme centrés sur les seuls champs de mise à jour.
///
/// Les cinq champs de tarification sont requis par le modèle mais n'ont aucun
/// rôle ici : les fixer une fois évite de les répéter à chaque cas et laisse
/// voir, à la lecture, ce que chaque test fait varier.
PlatformSettings _settings({
  String? minAppVersion,
  String? latestAppVersion,
  String? updateMessage,
  String? updateUrlAndroid,
  String? updateUrlIos,
}) => PlatformSettings(
  serviceFeePercent: 8,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 50,
  loyaltyMinRedemption: 100,
  referrerBonusPoints: 500,
  minAppVersion: minAppVersion,
  latestAppVersion: latestAppVersion,
  updateMessage: updateMessage,
  updateUrlAndroid: updateUrlAndroid,
  updateUrlIos: updateUrlIos,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService', () {
    late AppUpdateService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = AppUpdateService();
    });

    test('evaluates mandatory update when current < minAppVersion', () {
      final settings = _settings(
        minAppVersion: '2.0.0',
        latestAppVersion: '2.1.0',
        updateMessage: 'Mise à jour majeure obligatoire',
      );

      final info = service.evaluateUpdate(
        settings: settings,
        currentVersion: AppVersion.parse('1.2.7+32'),
      );

      expect(info.isMandatory, isTrue);
      expect(info.isOptional, isFalse);
      expect(info.requirement, equals(UpdateRequirement.mandatory));
      expect(info.minSupportedVersion, equals(AppVersion.parse('2.0.0')));
      expect(info.latestAvailableVersion, equals(AppVersion.parse('2.1.0')));
      expect(info.updateMessage, equals('Mise à jour majeure obligatoire'));
    });

    test('evaluates optional update when minVersion <= current < latestVersion', () {
      final settings = _settings(
        minAppVersion: '1.2.0',
        latestAppVersion: '1.3.0',
        updateMessage: 'Nouvelles fonctionnalités disponibles',
      );

      final info = service.evaluateUpdate(
        settings: settings,
        currentVersion: AppVersion.parse('1.2.7+32'),
      );

      expect(info.isMandatory, isFalse);
      expect(info.isOptional, isTrue);
      expect(info.requirement, equals(UpdateRequirement.optional));
    });

    test('evaluates requirement none when current >= latestVersion', () {
      final settings = _settings(
        minAppVersion: '1.0.0',
        latestAppVersion: '1.2.7+32',
      );

      final info = service.evaluateUpdate(
        settings: settings,
        currentVersion: AppVersion.parse('1.2.7+32'),
      );

      expect(info.isMandatory, isFalse);
      expect(info.isOptional, isFalse);
      expect(info.requirement, equals(UpdateRequirement.none));
    });

    test(
      'un minAppVersion mal formé ne bloque personne',
      () {
        // Le pire scénario de cette fonctionnalité n'est pas de rater une
        // mise à jour : c'est de **bloquer tout le parc** sur une faute de
        // frappe de l'administrateur. Une valeur illisible doit donc être
        // traitée comme « aucune contrainte », jamais interprétée au mieux.
        for (final malformed in ['1.2', '1.3.x', 'derniere', '', '  ']) {
          final info = service.evaluateUpdate(
            settings: _settings(minAppVersion: malformed),
            currentVersion: AppVersion.parse('1.2.7+32'),
          );
          expect(
            info.isMandatory,
            isFalse,
            reason: 'minAppVersion = "$malformed" a bloqué l\'application',
          );
          expect(info.requirement, UpdateRequirement.none);
        }
      },
    );

    test('une version sans build ne déclenche rien contre une version qui en a un',
        () {
      // Le serveur publie couramment « 1.2.7 » sans build. Comparé à
      // « 1.2.7+32 » installé, cela ne doit pas passer pour une version plus
      // récente : l'absence de build ne dit pas « build zéro ».
      final info = service.evaluateUpdate(
        settings: _settings(minAppVersion: '1.2.7', latestAppVersion: '1.2.7'),
        currentVersion: AppVersion.parse('1.2.7+32'),
      );

      expect(info.requirement, UpdateRequirement.none);
    });

    test('dismissOptionalUpdate suppresses prompt for 24 hours', () async {
      const versionKey = '1.3.0';
      expect(await service.shouldPromptOptionalUpdate(versionKey), isTrue);

      await service.dismissOptionalUpdate(versionKey);
      expect(await service.shouldPromptOptionalUpdate(versionKey), isFalse);
    });
  });
}
