import 'package:flutter/foundation.dart';
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

  group('Version installée inconnue', () {
    test('ne bloque personne : une inconnue n\'est pas un seuil', () {
      final info = AppUpdateService().evaluateUpdate(
        settings: _settings(minAppVersion: '9.0.0', latestAppVersion: '9.0.0'),
        currentVersion: null,
      );
      expect(info.requirement, UpdateRequirement.none);
    });
  });

  group('Comparaison (vecteurs communs backend / admin / app)', () {
    AppUpdateInfo eval(String current, {String? min, String? latest}) =>
        AppUpdateService().evaluateUpdate(
          settings: _settings(minAppVersion: min, latestAppVersion: latest),
          currentVersion: AppVersion.parse(current),
        );

    test('1.9.0 est sous 1.10.0 (numérique, pas lexicographique)', () {
      expect(eval('1.9.0', min: '1.10.0', latest: '1.10.0').isMandatory, isTrue);
    });
    test('1.10.0 n\'est pas sous 1.9.0', () {
      expect(eval('1.10.0', min: '1.9.0', latest: '2.0.0').isOptional, isTrue);
    });
    test('1.3.0+34 est sous 1.3.0+35', () {
      expect(eval('1.3.0+34', min: '1.3.0+35', latest: '1.3.0+40').isMandatory, isTrue);
    });
    test('1.3.1+35 installée satisfait min 1.3.1 (le piège UPD-001)', () {
      expect(eval('1.3.1+35', min: '1.3.1', latest: '1.3.1').requirement,
          UpdateRequirement.none);
    });
    test('pré-version côté serveur : ignorée', () {
      expect(eval('1.2.0', min: '1.3.0-beta').requirement, UpdateRequirement.none);
    });
  });

  group('openStore (UPD-002)', () {
    final info = AppUpdateService().evaluateUpdate(
      settings: _settings(
        minAppVersion: '2.0.0',
        latestAppVersion: '2.0.0',
        updateUrlAndroid:
            'https://play.google.com/store/apps/details?id=com.dreesis.lilia.lilia_app&hl=fr',
        updateUrlIos: 'https://apps.apple.com/app/lilia-food/id1234567890',
      ),
      currentVersion: AppVersion.parse('1.0.0'),
    );

    test('Android : fiche native, puis URL configurée, puis repli compilé', () {
      final service = AppUpdateService(
        platform: TargetPlatform.android,
        isWeb: false,
      );
      expect(service.storeCandidates(info).map((u) => u.scheme).toList(), [
        'market',
        'https',
        'https',
      ]);
    });

    test('Android : la fiche native ouverte → opened, sans essayer la suite', () async {
      final tried = <Uri>[];
      final service = AppUpdateService(
        platform: TargetPlatform.android,
        isWeb: false,
        canOpen: (_) async => true,
        open: (uri) async {
          tried.add(uri);
          return true;
        },
      );
      expect(await service.openStore(info), StoreOpenResult.opened);
      expect(tried.single.scheme, 'market');
    });

    test('Android sans Play Store : saute market:// et ouvre l\'URL https', () async {
      final tried = <Uri>[];
      final service = AppUpdateService(
        platform: TargetPlatform.android,
        isWeb: false,
        canOpen: (_) async => false,
        open: (uri) async {
          tried.add(uri);
          return true;
        },
      );
      expect(await service.openStore(info), StoreOpenResult.opened);
      expect(tried.single.host, 'play.google.com');
    });

    test('une exception passe à la destination suivante', () async {
      var calls = 0;
      final service = AppUpdateService(
        platform: TargetPlatform.iOS,
        isWeb: false,
        open: (uri) async {
          calls++;
          if (calls == 1) throw Exception('lien mort');
          return true;
        },
      );
      expect(await service.openStore(info), StoreOpenResult.opened);
      expect(calls, 2);
    });

    test('tout échoue → failed, jamais un faux succès', () async {
      final service = AppUpdateService(
        platform: TargetPlatform.iOS,
        isWeb: false,
        open: (_) async => false,
      );
      expect(await service.openStore(info), StoreOpenResult.failed);
      expect(service.storeName, "l'App Store");
      expect(service.fallbackLink(info), info.storeUrlIos);
    });

    test('URL configurée vide ou blanche → repli compilé', () {
      final blank = AppUpdateService().evaluateUpdate(
        settings: _settings(updateUrlAndroid: '  ', updateUrlIos: ''),
        currentVersion: AppVersion.parse('1.0.0'),
      );
      expect(blank.storeUrlAndroid, AppUpdateInfo.defaultStoreUrlAndroid);
      expect(blank.storeUrlIos, AppUpdateInfo.defaultStoreUrlIos);
    });
  });
}
