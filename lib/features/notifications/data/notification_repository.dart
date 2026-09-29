import 'package:lilia_app/core/storage/user_scoped_prefs.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Historique local des notifications reçues, **rangé par compte**.
///
/// Les titres et les corps décrivent des commandes : sous une clé globale, le
/// compte suivant sur le même téléphone les lisait tous. Voir
/// `user_scoped_prefs.dart`.
class NotificationRepository {
  NotificationRepository({required this.uid});

  /// `null` pour un visiteur — il a son propre seau.
  final String? uid;

  static const _notificationsKey = 'notifications_history';
  static const _lastSeenKey = 'notifications_last_seen';

  String get _cle => cleParCompte(_notificationsKey, uid);
  String get _cleVu => cleParCompte(_lastSeenKey, uid);

  /// Dernière ouverture de l'historique par ce compte ; `null` = jamais.
  ///
  /// Le badge comptait **tout** l'historique et ne redescendait jamais : un
  /// badge toujours allumé n'informe plus (P3-07). Une notification est « non
  /// lue » si elle est arrivée après cette date.
  Future<DateTime?> getLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cleVu);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastSeen(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleVu, at.toIso8601String());
  }

  Future<void> saveNotifications(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = notifications.map((n) => n.toJson()).toList();
    await prefs.setStringList(_cle, notificationsJson);
  }

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList(_cle);
    if (notificationsJson == null) {
      return [];
    }
    return notificationsJson
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cle);
  }
}
