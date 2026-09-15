import 'app_version.dart';

/// Type d'exigence de mise à jour.
enum UpdateRequirement {
  /// L'application est à jour.
  none,

  /// Une version plus récente existe, mais la version actuelle reste supportée.
  optional,

  /// La version actuelle n'est plus supportée (faille critique, rupture contrat API).
  mandatory,
}

/// Informations sur l'état de mise à jour de l'application.
class AppUpdateInfo {
  final UpdateRequirement requirement;
  final AppVersion currentVersion;
  final AppVersion? minSupportedVersion;
  final AppVersion? latestAvailableVersion;
  final String? updateMessage;
  final String storeUrlAndroid;
  final String storeUrlIos;

  const AppUpdateInfo({
    required this.requirement,
    required this.currentVersion,
    this.minSupportedVersion,
    this.latestAvailableVersion,
    this.updateMessage,
    this.storeUrlAndroid =
        'https://play.google.com/store/apps/details?id=com.dreesis.lilia.lilia_app',
    this.storeUrlIos =
        'https://apps.apple.com/app/lilia-food/id6740000000',
  });

  bool get isMandatory => requirement == UpdateRequirement.mandatory;
  bool get isOptional => requirement == UpdateRequirement.optional;
  bool get hasUpdate => isMandatory || isOptional;
}
