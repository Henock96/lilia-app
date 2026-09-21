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
    // ⚠️ Une **recherche**, pas une fiche — et c'est délibéré.
    //
    // Ce repli valait `https://apps.apple.com/app/lilia-food/id6740000000` :
    // un identifiant App Store manifestement fabriqué (un nombre rond de dix
    // chiffres). En mise à jour **obligatoire**, le client se retrouvait
    // enfermé dans une boîte de dialogue dont le seul bouton ouvrait une page
    // inexistante — bloqué, sans recours.
    //
    // Une recherche aboutit toujours quelque part. Ce n'est pas la bonne
    // réponse : la bonne réponse est de renseigner `updateUrlIos` dans
    // `PlatformSettings`, ce qui court-circuite entièrement ce repli. Mais
    // c'est une impasse de moins tant que ce n'est pas fait.
    this.storeUrlIos = 'https://apps.apple.com/search?term=Lilia%20Food',
  });

  bool get isMandatory => requirement == UpdateRequirement.mandatory;
  bool get isOptional => requirement == UpdateRequirement.optional;
  bool get hasUpdate => isMandatory || isOptional;
}
