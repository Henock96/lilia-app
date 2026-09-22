import 'package:flutter/foundation.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_version.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lilia_app/core/log.dart';

part 'app_update_service.g.dart';

/// `applicationId` Android de cette app (`android/app/build.gradle.kts`).
/// Le serveur n'accepte, en `updateUrlAndroid`, que des fiches de cet
/// identifiant (`app-update-policy.ts`, `ANDROID_APPLICATION_ID`).
const kAndroidApplicationId = 'com.dreesis.lilia.lilia_app';

/// Issue d'une tentative d'ouverture du store.
///
/// `openStore` rendait un `bool` que personne ne lisait : le bouton du
/// dialogue **obligatoire** appelait `service.openStore(info)` et ignorait le
/// résultat. Un lien mort laissait l'utilisateur devant un dialogue non
/// fermable dont le seul bouton ne faisait rien, sans un mot (UPD-002).
enum StoreOpenResult {
  /// Le système a accepté d'ouvrir une destination.
  opened,

  /// Aucune destination n'a pu être ouverte : l'appelant **doit** le dire.
  failed,
}

/// Peut-on ouvrir cette URI ? (`canLaunchUrl` par défaut)
typedef CanOpenUri = Future<bool> Function(Uri uri);

/// Ouvre l'URI hors de l'app ; `true` si le système l'a acceptée.
typedef OpenUri = Future<bool> Function(Uri uri);

Future<bool> _defaultOpen(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Service centralisé de gestion des mises à jour de l'application.
class AppUpdateService {
  AppUpdateService({
    CanOpenUri canOpen = canLaunchUrl,
    OpenUri open = _defaultOpen,
    TargetPlatform? platform,
    bool? isWeb,
  }) : _canOpen = canOpen,
       _open = open,
       _platform = platform,
       _isWeb = isWeb ?? kIsWeb;

  final CanOpenUri _canOpen;
  final OpenUri _open;
  final TargetPlatform? _platform;
  final bool _isWeb;

  static const _prefDismissPrefix = 'lilia_update_dismissed_';
  static const _dismissDuration = Duration(hours: 24);

  TargetPlatform get _targetPlatform => _platform ?? defaultTargetPlatform;

  /// Évalue les paramètres de la plateforme pour déterminer l'exigence de mise à jour.
  ///
  /// [currentVersion] est la version **installée** (`AppVersion.installed`).
  /// `null` — plateforme muette ou version illisible — ne bloque personne :
  /// on n'enferme pas un utilisateur sur une inconnue.
  AppUpdateInfo evaluateUpdate({
    required PlatformSettings settings,
    required AppVersion? currentVersion,
  }) {
    final minVersion = AppVersion.tryParse(settings.minAppVersion);
    final latestVersion = AppVersion.tryParse(settings.latestAppVersion);

    UpdateRequirement requirement = UpdateRequirement.none;

    if (currentVersion != null) {
      if (minVersion != null && currentVersion < minVersion) {
        requirement = UpdateRequirement.mandatory;
      } else if (latestVersion != null && currentVersion < latestVersion) {
        requirement = UpdateRequirement.optional;
      }
    }

    final message = settings.updateMessage?.trim();
    return AppUpdateInfo(
      requirement: requirement,
      currentVersion: currentVersion,
      minSupportedVersion: minVersion,
      latestAvailableVersion: latestVersion,
      updateMessage: (message == null || message.isEmpty) ? null : message,
      storeUrlAndroid: _nonBlank(settings.updateUrlAndroid) ??
          AppUpdateInfo.defaultStoreUrlAndroid,
      storeUrlIos:
          _nonBlank(settings.updateUrlIos) ?? AppUpdateInfo.defaultStoreUrlIos,
    );
  }

  static String? _nonBlank(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Destinations essayées, dans l'ordre, pour la plateforme courante.
  ///
  /// Android : la fiche **native** d'abord (`market://`, ouvre le Play Store
  /// sans passer par le navigateur), puis l'URL configurée — qui reste la
  /// seule issue sur un appareil sans Play Store (Huawei). `market` est
  /// déclaré dans les `<queries>` du manifeste : sans cette déclaration,
  /// `canLaunchUrl` répondait `false` sous Android 11+ et l'étape native
  /// n'était jamais tentée.
  @visibleForTesting
  List<Uri> storeCandidates(AppUpdateInfo info) {
    final candidates = <Uri>[];
    void add(String raw) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.hasScheme && !candidates.contains(uri)) {
        candidates.add(uri);
      }
    }

    if (!_isWeb && _targetPlatform == TargetPlatform.android) {
      add('market://details?id=$kAndroidApplicationId');
      add(info.storeUrlAndroid);
      add(AppUpdateInfo.defaultStoreUrlAndroid);
    } else if (!_isWeb && _targetPlatform == TargetPlatform.iOS) {
      add(info.storeUrlIos);
      add(AppUpdateInfo.defaultStoreUrlIos);
    } else {
      add(info.storeUrlAndroid);
    }
    return candidates;
  }

  /// Ouvre le store approprié et **dit si c'est arrivé**.
  ///
  /// Chaque destination est essayée à son tour ; une exception ou un refus du
  /// système passe à la suivante. La dernière de chaque plateforme est le
  /// repli compilé dans le binaire — une URL configurée invalide n'est donc
  /// jamais la seule issue.
  Future<StoreOpenResult> openStore(AppUpdateInfo info) async {
    final candidates = storeCandidates(info);
    for (var i = 0; i < candidates.length; i++) {
      final uri = candidates[i];
      try {
        // La fiche native n'est tentée que si une app sait la traiter : sur un
        // appareil sans Play Store, `launchUrl` lèverait ou ouvrirait un
        // sélecteur vide.
        if (uri.scheme == 'market' && !await _canOpen(uri)) continue;
        if (await _open(uri)) return StoreOpenResult.opened;
      } catch (e) {
        logDebug('Ouverture du store impossible ($uri) : $e');
      }
    }
    return StoreOpenResult.failed;
  }

  /// Nom du store à citer dans un message d'échec.
  String get storeName => _targetPlatform == TargetPlatform.iOS && !_isWeb
      ? "l'App Store"
      : 'Google Play';

  /// Lien à proposer à la copie quand aucune ouverture n'a abouti.
  String fallbackLink(AppUpdateInfo info) =>
      _targetPlatform == TargetPlatform.iOS && !_isWeb
      ? info.storeUrlIos
      : info.storeUrlAndroid;

  /// Vérifie si la notification de mise à jour facultative doit être affichée.
  /// Évite de harceler l'utilisateur s'il a cliqué "Plus tard" dans les dernières 24h.
  Future<bool> shouldPromptOptionalUpdate(String versionKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefDismissPrefix$versionKey';
      final timestamp = prefs.getInt(key);
      if (timestamp == null) return true;

      final dismissedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(dismissedAt) > _dismissDuration;
    } catch (_) {
      return true;
    }
  }

  /// Mémorise le report d'une mise à jour facultative pour 24h.
  Future<void> dismissOptionalUpdate(String versionKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefDismissPrefix$versionKey';
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

@Riverpod(keepAlive: true)
AppUpdateService appUpdateService(Ref ref) => AppUpdateService();

/// Version installée, lue une fois dans le binaire (`package_info_plus`).
@Riverpod(keepAlive: true)
Future<AppVersion?> installedAppVersion(Ref ref) => AppVersion.installed();

/// Fournit l'état calculé de la mise à jour courante à partir de PlatformSettings.
@riverpod
Future<AppUpdateInfo> appUpdateInfo(Ref ref) async {
  final settings = await ref.watch(platformSettingsProvider.future);
  final current = await ref.watch(installedAppVersionProvider.future);
  final service = ref.watch(appUpdateServiceProvider);
  return service.evaluateUpdate(settings: settings, currentVersion: current);
}
