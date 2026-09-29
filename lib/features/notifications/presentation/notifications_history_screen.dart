import 'package:flutter/material.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';

class NotificationsHistoryScreen extends ConsumerStatefulWidget {
  const NotificationsHistoryScreen({super.key});

  @override
  ConsumerState<NotificationsHistoryScreen> createState() =>
      _NotificationsHistoryScreenState();
}

class _NotificationsHistoryScreenState
    extends ConsumerState<NotificationsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Ouvrir l'historique = tout lire : le badge de l'accueil s'éteint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsLastSeenProvider.notifier).markAllSeen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(notificationHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(notificationHistoryProvider.notifier).clearHistory();
            },
            tooltip: 'Effacer l\'historique',
          ),
        ],
      ),
      body: history.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Text('Aucune notification pour le moment.'),
            );
          }
          // Antéchronologique, par date **explicite** : la liste est stockée
          // récente d'abord, et l'ancien `.reversed` l'affichait donc de la
          // plus ancienne à la plus récente.
          final reversedList = [...notifications]
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return ListView.builder(
            itemCount: reversedList.length,
            itemBuilder: (context, index) {
              final notification = reversedList[index];
              return ListTile(
                leading: const Icon(Icons.notifications_active),
                title: Text(notification.title),
                subtitle: Text(notification.body),
                trailing: Text(
                  notificationTimeLabel(notification.timestamp, DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => BuildErrorState(err),
      ),
    );
  }
}

/// « 14:05 » aujourd'hui, « 28/09 14:05 » avant : l'heure seule faisait
/// passer une notification d'avant-hier pour une nouvelle.
String notificationTimeLabel(DateTime at, DateTime now) {
  final local = at.toLocal();
  final n = now.toLocal();
  final sameDay =
      local.year == n.year && local.month == n.month && local.day == n.day;
  return sameDay
      ? DateFormat.Hm().format(local)
      : DateFormat('dd/MM HH:mm').format(local);
}
