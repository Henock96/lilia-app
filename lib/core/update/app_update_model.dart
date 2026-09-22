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
  /// Version installée ; `null` si la plateforme ne l'a pas fournie.
  final AppVersion? currentVersion;
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
    this.storeUrlAndroid = defaultStoreUrlAndroid,
    this.storeUrlIos = defaultStoreUrlIos,
  });

  /// Fiche Play de l'app — repli compilé, vérifié : c'est l'`applicationId`
  /// réel (`android/app/build.gradle.kts`).
  static const defaultStoreUrlAndroid =
      'https://play.google.com/store/apps/details?id=com.dreesis.lilia.lilia_app';

  /// ⚠️ Une **recherche**, pas une fiche — et c'est délibéré.
  ///
  /// Ce repli valait `https://apps.apple.com/app/lilia-food/id6740000000` :
  /// un identifiant App Store fabriqué. En mise à jour **obligatoire**, le
  /// client se retrouvait enfermé devant une page inexistante. Une recherche
  /// aboutit toujours quelque part. La bonne réponse reste de renseigner
  /// `updateUrlIos` — le serveur n'y accepte plus qu'une vraie fiche
  /// (`apps.apple.com/…/id<chiffres>`) — mais l'app n'est pas encore publiée
  /// sur l'App Store (22/09/2026).
  static const defaultStoreUrlIos =
      'https://apps.apple.com/search?term=Lilia%20Food';

  bool get isMandatory => requirement == UpdateRequirement.mandatory;
  bool get isOptional => requirement == UpdateRequirement.optional;
  bool get hasUpdate => isMandatory || isOptional;
}
