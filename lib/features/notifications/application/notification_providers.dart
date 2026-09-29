import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/features/notifications/data/notification_repository.dart';
import '../../../services/notification_router.dart';
import '../../auth/repository/firebase_auth_repository.dart';

part 'notification_providers.g.dart';

/// Provider to hold the ID of the most recently updated order.
final latestUpdatedOrderIdProvider = StateProvider<String?>((ref) => null);

/// Intention issue de la dernière notification, à consommer par l'écran de
/// détail de commande.
///
/// Le service de notification se contentait de recharger la liste, quel que
/// soit l'événement : impossible de distinguer une livraison terminée d'un
/// paiement échoué. `NotificationRouter` produit désormais une intention, et
/// c'est ici qu'elle attend d'être lue.
///
/// `null` quand il n'y a rien à proposer. L'écran doit la remettre à `null`
/// après traitement — sinon revenir sur la commande rouvrirait indéfiniment
/// la même invitation.
final pendingNotificationIntentProvider =
    StateProvider<({String orderId, NotificationIntent intent})?>(
      (ref) => null,
    );

@riverpod
NotificationRepository notificationRepository(Ref ref) {
  // `watch` : à la déconnexion, le dépôt est reconstruit sur le seau du
  // visiteur, et l'historique du compte parti cesse d'être lisible.
  return NotificationRepository(
    uid: ref.watch(authRepositoryProvider).currentUser?.uid,
  );
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

/// Date de dernière consultation de l'historique (P3-07), par compte.
@riverpod
class NotificationsLastSeen extends _$NotificationsLastSeen {
  @override
  Future<DateTime?> build() =>
      ref.watch(notificationRepositoryProvider).getLastSeen();

  /// Appelé à l'ouverture de l'historique : tout ce qui est affiché est lu.
  Future<void> markAllSeen({DateTime? at}) async {
    final now = at ?? DateTime.now();
    state = AsyncData(now);
    await ref.read(notificationRepositoryProvider).setLastSeen(now);
  }
}

/// Nombre de notifications arrivées depuis la dernière consultation.
///
/// Fonction pure, testée : c'est elle qui décide du badge.
int countUnread(List<AppNotification> notifications, DateTime? lastSeen) =>
    lastSeen == null
    ? notifications.length
    : notifications.where((n) => n.timestamp.isAfter(lastSeen)).length;

@riverpod
int unreadNotificationCount(Ref ref) {
  final history = ref.watch(notificationHistoryProvider).value;
  if (history == null) return 0;
  // Tant que la date n'est pas lue, on ne compte rien plutôt que tout : un
  // badge « 23 » qui clignote puis s'éteint au démarrage serait pire.
  final lastSeen = ref.watch(notificationsLastSeenProvider);
  if (!lastSeen.hasValue) return 0;
  return countUnread(history, lastSeen.value);
}
