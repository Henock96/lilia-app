// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationRepositoryHash() =>
    r'c074cdb2ba4209a3ef964e424f6d6407f9da0e10';

/// See also [notificationRepository].
@ProviderFor(notificationRepository)
final notificationRepositoryProvider =
    AutoDisposeProvider<NotificationRepository>.internal(
      notificationRepository,
      name: r'notificationRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationRepositoryRef =
    AutoDisposeProviderRef<NotificationRepository>;
String _$notificationHistoryHash() =>
    r'82aaef354df8cc0e69a6e74ec473324171fd79ba';

/// See also [NotificationHistory].
@ProviderFor(NotificationHistory)
final notificationHistoryProvider =
    AutoDisposeAsyncNotifierProvider<
      NotificationHistory,
      List<AppNotification>
    >.internal(
      NotificationHistory.new,
      name: r'notificationHistoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationHistoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NotificationHistory = AutoDisposeAsyncNotifier<List<AppNotification>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
