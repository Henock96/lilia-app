import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';

class NotificationsHistoryScreen extends ConsumerWidget {
  const NotificationsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Afficher la liste en ordre antéchronologique
          final reversedList = notifications.reversed.toList();
          return ListView.builder(
            itemCount: reversedList.length,
            itemBuilder: (context, index) {
              final notification = reversedList[index];
              return ListTile(
                leading: const Icon(Icons.notifications_active),
                title: Text(notification.title),
                subtitle: Text(notification.body),
                trailing: Text(
                  DateFormat.Hm().format(notification.timestamp), // Heure:Minute
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }
}
