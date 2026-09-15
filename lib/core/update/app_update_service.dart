import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_version.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part 'app_update_service.g.dart';

/// Service centralisé de gestion des mises à jour de l'application.
class AppUpdateService {
  static const _prefDismissPrefix = 'lilia_update_dismissed_';
  static const _dismissDuration = Duration(hours: 24);

  /// Évalue les paramètres de la plateforme pour déterminer l'exigence de mise à jour.
  AppUpdateInfo evaluateUpdate({
    required PlatformSettings settings,
    AppVersion currentVersion = AppVersion.current,
  }) {
    final minVersion = AppVersion.tryParse(settings.minAppVersion);
    final latestVersion = AppVersion.tryParse(settings.latestAppVersion);

    UpdateRequirement requirement = UpdateRequirement.none;

    if (minVersion != null && currentVersion < minVersion) {
      requirement = UpdateRequirement.mandatory;
    } else if (latestVersion != null && currentVersion < latestVersion) {
      requirement = UpdateRequirement.optional;
    }

    return AppUpdateInfo(
      requirement: requirement,
      currentVersion: currentVersion,
      minSupportedVersion: minVersion,
      latestAvailableVersion: latestVersion,
      updateMessage: settings.updateMessage,
      storeUrlAndroid: settings.updateUrlAndroid ??
          'https://play.google.com/store/apps/details?id=com.dreesis.lilia.lilia_app',
      storeUrlIos: settings.updateUrlIos ??
          'https://apps.apple.com/app/lilia-food/id6740000000',
    );
  }

  /// Ouvre le store approprié (Google Play Store ou Apple App Store).
  Future<bool> openStore(AppUpdateInfo info) async {
    if (!kIsWeb && Platform.isAndroid) {
      // 1. Essayer le lien market natif
      final marketUri = Uri.parse('market://details?id=com.dreesis.lilia.lilia_app');
      if (await canLaunchUrl(marketUri)) {
        try {
          final launched = await launchUrl(
            marketUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}
      }

      // 2. Repli URL Play Store
      final playStoreUri = Uri.parse(info.storeUrlAndroid);
      try {
        return await launchUrl(
          playStoreUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('Failed to launch Play Store URL: $e');
        return false;
      }
    }

    if (!kIsWeb && Platform.isIOS) {
      // 1. Essayer le lien itms-apps natif si URL http standard
      final appStoreUri = Uri.parse(info.storeUrlIos);
      try {
        return await launchUrl(
          appStoreUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('Failed to launch App Store URL: $e');
        return false;
      }
    }

    // Web fallback
    final fallbackUri = Uri.parse(info.storeUrlAndroid);
    try {
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

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

/// Fournit l'état calculé de la mise à jour courante à partir de PlatformSettings.
@riverpod
Future<AppUpdateInfo> appUpdateInfo(Ref ref) async {
  final settings = await ref.watch(platformSettingsProvider.future);
  final service = ref.watch(appUpdateServiceProvider);
  return service.evaluateUpdate(settings: settings);
}
