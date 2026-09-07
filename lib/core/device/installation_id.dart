import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identifiant **d'installation** de l'application.
///
/// ## Ce que c'est
///
/// Un UUID v4 tiré au premier lancement et conservé dans les préférences
/// locales. Il est envoyé au serveur en en-tête `X-Lilia-Installation-Id`, où
/// il sert de signal anti-abus au parrainage : plusieurs comptes nés de la
/// même installation pèsent sur la décision de récompenser un parrain.
///
/// ## Ce que ce n'est pas
///
/// Ce n'est **pas** un identifiant d'appareil, et volontairement pas.
///
/// Aucune donnée matérielle n'est lue — ni IMEI, ni adresse MAC, ni numéro de
/// série. Leur accès est restreint sur Android comme sur iOS, et surtout ils
/// n'apporteraient rien pour l'usage visé : on cherche à repérer une série de
/// comptes créés au même endroit, pas à identifier une personne.
///
/// Conséquences assumées :
///  · désinstaller l'application remet le compteur à zéro ;
///  · un téléphone prêté fait apparaître deux comptes sur la même installation.
///
/// C'est pourquoi le serveur ne s'en sert que pour **pondérer** une décision.
/// La logique anti-fraude n'est pas ici et ne doit jamais y venir : un client
/// est modifiable par qui le fait tourner.
class InstallationId {
  InstallationId._();

  static const _storageKey = 'lilia_installation_id';

  /// Mémorisé pour le reste de la session : la valeur ne change jamais et
  /// l'en-tête est posé sur chaque requête.
  static String? _cached;

  /// Retourne l'identifiant, en le créant au premier appel.
  ///
  /// Ne lève jamais : un stockage local indisponible ne doit pas empêcher
  /// l'application de démarrer. Dans ce cas l'identifiant reste `null` et le
  /// serveur traite le signal comme absent — ce qu'il sait faire.
  static Future<String?> get() async {
    if (_cached != null) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      var value = prefs.getString(_storageKey);
      if (value == null || value.isEmpty) {
        value = _generateUuidV4();
        await prefs.setString(_storageKey, value);
      }
      _cached = value;
      return value;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('InstallationId indisponible : $e');
      }
      return null;
    }
  }

  /// Plateforme déclarée, envoyée en `X-Lilia-Platform`. Purement indicative.
  static String get platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// UUID v4 à partir de [Random.secure].
  ///
  /// Écrit à la main pour ne pas ajouter une dépendance à `uuid` pour seize
  /// octets. `Random.secure()` est indispensable : un identifiant prévisible
  /// permettrait à un fraudeur de se faire passer pour une installation neuve
  /// à chaque compte.
  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @visibleForTesting
  static void resetCacheForTest() => _cached = null;

  @visibleForTesting
  static String generateForTest() => _generateUuidV4();
}
