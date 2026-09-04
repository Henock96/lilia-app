import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/features/notifications/data/notification_repository.dart';
import '../../../services/notification_router.dart';

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
