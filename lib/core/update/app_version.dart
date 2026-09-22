import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

/// Représentation sémantique d'une version d'application (`1.2.7`, `1.2.7+32`).
///
/// ## Pourquoi le parsing est strict
///
/// Cette valeur arrive du serveur (`PlatformSettings.minAppVersion`) et peut
/// **bloquer l'application** : en dessous du seuil, le client ne peut plus
/// commander tant qu'il n'a pas mis à jour. Une saisie approximative de
/// l'administrateur — `1.2`, `1.2.x`, `v1.2.7-beta` — ne doit donc jamais être
/// interprétée « au mieux ».
///
/// Une version tolérante qui transformait `1.2` en `1.2.0` produisait un seuil
/// valide à partir d'une faute de frappe. Ici, tout ce qui n'est pas
/// `major.minor.patch` (avec `+build` optionnel) rend `null`, et l'appelant
/// traite l'absence de seuil comme « aucune contrainte » — le repli sûr.
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;

  /// Numéro de build (`+32`). `null` quand la version n'en porte pas : c'est
  /// une information *absente*, pas un build numéro zéro. La distinction
  /// compte dans [compareTo], où deux versions dont l'une ignore son build ne
  /// se départagent pas dessus.
  final int? buildNumber;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber,
  });

  /// Version **réellement installée**, lue dans le binaire au démarrage.
  ///
  /// ## Pourquoi ce n'est plus une constante (UPD-001)
  ///
  /// La version vivait en dur ici (`static const current = 1.3.0+34`) pendant
  /// que `pubspec.yaml` passait à `1.3.1+35`. Le test de garde échouait, mais
  /// rien ne l'exécutait avant une release. Publier ce binaire puis poser
  /// `minAppVersion = 1.3.1` aurait bloqué **à vie** les utilisateurs déjà mis
  /// à jour : leur application se déclarait toujours 1.3.0+34, sous le seuil,
  /// et les renvoyait au store — qui leur servait la version qu'ils avaient.
  ///
  /// La version vient désormais de `package_info_plus`, c'est-à-dire de ce que
  /// Flutter a compilé depuis `pubspec.yaml` (`versionName`/`versionCode`
  /// Android, `CFBundleShortVersionString`/`CFBundleVersion` iOS). Il n'y a
  /// plus de seconde copie à oublier.
  ///
  /// `null` si la plateforme ne répond pas ou si la version est illisible :
  /// l'appelant traite alors l'absence comme « aucune contrainte », jamais
  /// comme un blocage — on ne bloque pas un utilisateur sur une inconnue.
  ///
  /// ⚠️ `flutter build apk --split-per-abi` ajoute un décalage par ABI au
  /// `versionCode` (1000 + build…) : le build lu ici ne serait plus celui du
  /// pubspec. Publier en `appbundle`, ce que fait déjà le projet.
  static Future<AppVersion?> installed() {
    return _installed ??= _readInstalled();
  }

  static Future<AppVersion?>? _installed;

  static Future<AppVersion?> _readInstalled() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return fromPlatform(version: info.version, buildNumber: info.buildNumber);
    } catch (_) {
      return null;
    }
  }

  /// Compose la version depuis les deux champs de la plateforme.
  ///
  /// `buildNumber` peut être vide (web, certains bancs de test) : la version
  /// est alors lue sans build, ce que [compareTo] sait traiter.
  static AppVersion? fromPlatform({
    required String version,
    required String buildNumber,
  }) {
    final build = buildNumber.trim();
    return tryParse(build.isEmpty ? version : '$version+$build');
  }

  /// Réinitialise le cache de [installed] — tests uniquement.
  @visibleForTesting
  static void resetInstalledForTest() => _installed = null;

  /// Motif accepté : `1.2.7`, `1.2.7+32`, avec `v` initial et espaces tolérés.
  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

  /// Parse une version, ou rend `null` si la chaîne n'est pas exactement au
  /// format attendu.
  static AppVersion? tryParse(String? input) {
    if (input == null) return null;
    var sanitized = input.trim();
    if (sanitized.isEmpty) return null;
    if (sanitized.startsWith('v') || sanitized.startsWith('V')) {
      sanitized = sanitized.substring(1);
    }

    final match = _pattern.firstMatch(sanitized);
    if (match == null) return null;

    final build = match.group(4);
    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      buildNumber: build == null ? null : int.parse(build),
    );
  }

  /// Comme [tryParse], mais lève sur une chaîne invalide.
  ///
  /// Réservé aux versions écrites dans le code et aux tests, où une chaîne
  /// fautive est un bug à faire remonter tout de suite. Pour une valeur venue
  /// du réseau, utiliser [tryParse] et traiter `null`.
  static AppVersion parse(String input) {
    final parsed = tryParse(input);
    if (parsed == null) {
      throw FormatException('Version invalide', input);
    }
    return parsed;
  }

  /// Ordre : majeure, mineure, correctif, puis build.
  ///
  /// Le build ne départage que si les **deux** versions en portent un. Comparer
  /// `1.2.7+32` à `1.2.7` reviendrait sinon à décider que la seconde est plus
  /// ancienne, alors qu'elle ne dit simplement rien de son build — et le
  /// serveur, qui publie souvent `minAppVersion: "1.3.0"` sans build, aurait
  /// déclenché une mise à jour obligatoire à tort.
  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    final a = buildNumber;
    final b = other.buildNumber;
    if (a == null || b == null) return 0;
    return a.compareTo(b);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          buildNumber == other.buildNumber;

  @override
  int get hashCode => Object.hash(major, minor, patch, buildNumber);

  @override
  String toString() => buildNumber != null
      ? '$major.$minor.$patch+$buildNumber'
      : '$major.$minor.$patch';
}
