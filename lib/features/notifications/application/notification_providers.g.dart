// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationRepository)
final notificationRepositoryProvider = NotificationRepositoryProvider._();

final class NotificationRepositoryProvider
    extends
        $FunctionalProvider<
          NotificationRepository,
          NotificationRepository,
          NotificationRepository
        >
    with $Provider<NotificationRepository> {
  NotificationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationRepositoryHash();

  @$internal
  @override
  $ProviderElement<NotificationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationRepository create(Ref ref) {
    return notificationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationRepository>(value),
    );
  }
}

String _$notificationRepositoryHash() =>
    r'bf817ee3a97bd936aeeaf8b4a49f99615197d139';

@ProviderFor(NotificationHistory)
final notificationHistoryProvider = NotificationHistoryProvider._();

final class NotificationHistoryProvider
    extends $AsyncNotifierProvider<NotificationHistory, List<AppNotification>> {
  NotificationHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationHistoryHash();

  @$internal
  @override
  NotificationHistory create() => NotificationHistory();
}

String _$notificationHistoryHash() =>
    r'82aaef354df8cc0e69a6e74ec473324171fd79ba';

abstract class _$NotificationHistory
    extends $AsyncNotifier<List<AppNotification>> {
  FutureOr<List<AppNotification>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<AppNotification>>, List<AppNotification>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<AppNotification>>,
                List<AppNotification>
              >,
              AsyncValue<List<AppNotification>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Date de dernière consultation de l'historique (P3-07), par compte.

@ProviderFor(NotificationsLastSeen)
final notificationsLastSeenProvider = NotificationsLastSeenProvider._();

/// Date de dernière consultation de l'historique (P3-07), par compte.
final class NotificationsLastSeenProvider
    extends $AsyncNotifierProvider<NotificationsLastSeen, DateTime?> {
  /// Date de dernière consultation de l'historique (P3-07), par compte.
  NotificationsLastSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsLastSeenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsLastSeenHash();

  @$internal
  @override
  NotificationsLastSeen create() => NotificationsLastSeen();
}

String _$notificationsLastSeenHash() =>
    r'8c6fb9fab607a1796320494644f8b1f16f5b9b0e';

/// Date de dernière consultation de l'historique (P3-07), par compte.

abstract class _$NotificationsLastSeen extends $AsyncNotifier<DateTime?> {
  FutureOr<DateTime?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DateTime?>, DateTime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DateTime?>, DateTime?>,
              AsyncValue<DateTime?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(unreadNotificationCount)
final unreadNotificationCountProvider = UnreadNotificationCountProvider._();

final class UnreadNotificationCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  UnreadNotificationCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNotificationCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNotificationCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadNotificationCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadNotificationCountHash() =>
    r'e2d7487bdc87fa7d7cc9dcb031ffc91e4b9e885f';
