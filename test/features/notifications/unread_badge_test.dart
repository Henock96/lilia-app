// P3-07 — le badge compte les notifications non lues, pas tout l'historique.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/features/notifications/data/notification_repository.dart';
import 'package:lilia_app/features/notifications/presentation/notifications_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppNotification _notif(String id, DateTime at) => AppNotification(
  id: id,
  title: 'Titre $id',
  body: 'Corps $id',
  timestamp: at,
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final t0 = DateTime(2026, 9, 29, 10);

  group('countUnread', () {
    final liste = [
      _notif('c', t0.add(const Duration(hours: 2))),
      _notif('b', t0.add(const Duration(hours: 1))),
      _notif('a', t0),
    ];

    test('jamais consulté : tout est non lu', () {
      expect(countUnread(liste, null), 3);
    });

    test('seules les arrivées après la consultation comptent', () {
      expect(countUnread(liste, t0.add(const Duration(minutes: 30))), 2);
      expect(countUnread(liste, t0.add(const Duration(hours: 3))), 0);
    });
  });

  test('provider : consulter remet le compteur à zéro, par compte', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = NotificationRepository(uid: 'uid-a');
    await repo.saveNotifications([_notif('a', t0), _notif('b', t0)]);

    final c = ProviderContainer(
      overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(unreadNotificationCountProvider, (_, _) {});
    await c.read(notificationHistoryProvider.future);
    await c.read(notificationsLastSeenProvider.future);
    expect(c.read(unreadNotificationCountProvider), 2);

    await c
        .read(notificationsLastSeenProvider.notifier)
        .markAllSeen(at: t0.add(const Duration(minutes: 1)));
    expect(c.read(unreadNotificationCountProvider), 0);

    // Persisté : un redémarrage ne rallume pas le badge.
    expect(await repo.getLastSeen(), t0.add(const Duration(minutes: 1)));
    // Un autre compte a son propre état.
    expect(await NotificationRepository(uid: 'uid-b').getLastSeen(), isNull);
  });

  testWidgets('l\'historique s\'affiche du plus récent au plus ancien', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = NotificationRepository(uid: 'uid-a');
    // Stocké récent d'abord, comme le fait `addNotification`.
    await repo.saveNotifications([
      _notif('recente', DateTime.now()),
      _notif('ancienne', DateTime.now().subtract(const Duration(days: 2))),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NotificationsHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final recente = tester.getTopLeft(find.text('Titre recente')).dy;
    final ancienne = tester.getTopLeft(find.text('Titre ancienne')).dy;
    expect(recente, lessThan(ancienne));
    expect(await repo.getLastSeen(), isNotNull, reason: 'ouvrir = lire');
  });

  test('libellé horaire : date affichée si ce n\'est pas aujourd\'hui', () {
    final now = DateTime(2026, 9, 29, 18);
    expect(notificationTimeLabel(DateTime(2026, 9, 29, 14, 5), now), '14:05');
    expect(
      notificationTimeLabel(DateTime(2026, 9, 27, 14, 5), now),
      '27/09 14:05',
    );
  });
}
