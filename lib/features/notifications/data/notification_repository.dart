import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationRepository {
  static const _notificationsKey = 'notifications_history';

  Future<void> saveNotifications(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = notifications.map((n) => n.toJson()).toList();
    await prefs.setStringList(_notificationsKey, notificationsJson);
  }

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList(_notificationsKey);
    if (notificationsJson == null) {
      return [];
    }
    return notificationsJson
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
  }
}
