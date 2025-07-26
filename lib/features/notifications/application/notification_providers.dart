import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/features/notifications/data/notification_repository.dart';
import 'package:lilia_app/features/notifications/data/notification_service.dart';

part 'notification_providers.g.dart';

@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  return NotificationService();
}

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  return NotificationRepository();
}

@riverpod
Stream<AppNotification> notificationStream(NotificationStreamRef ref) {
  return ref.watch(notificationServiceProvider).connect();
}

@riverpod
class NotificationHistory extends _$NotificationHistory {
  @override
  Future<List<AppNotification>> build() async {
    // Charger l'historique initial depuis SharedPreferences
    return ref.watch(notificationRepositoryProvider).getNotifications();
  }

  Future<void> addNotification(AppNotification notification) async {
    // Mettre à jour l'état avec la nouvelle notification
    state = AsyncData([...await future, notification]);
    // Sauvegarder la liste mise à jour
    await ref.read(notificationRepositoryProvider).saveNotifications(state.value!);
  }

  Future<void> clearHistory() async {
    state = const AsyncData([]);
    await ref.read(notificationRepositoryProvider).clearNotifications();
  }
}
