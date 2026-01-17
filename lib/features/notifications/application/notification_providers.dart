import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/features/notifications/data/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'notification_providers.g.dart';

/// Provider to hold the ID of the most recently updated order.
final latestUpdatedOrderIdProvider = StateProvider<String?>((ref) => null);

@riverpod
NotificationRepository notificationRepository(Ref ref) {
  return NotificationRepository();
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
    final currentState = await future;
    state = AsyncData([notification, ...currentState]); // Ajoute au début
    // Sauvegarder la liste mise à jour
    await ref
        .read(notificationRepositoryProvider)
        .saveNotifications(state.value!);
  }

  Future<void> clearHistory() async {
    state = const AsyncData([]);
    await ref.read(notificationRepositoryProvider).clearNotifications();
  }
}
