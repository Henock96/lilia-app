// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationServiceHash() =>
    r'6db295591da0ebe2efdebffe326d89912af46b5a';

/// See also [notificationService].
@ProviderFor(notificationService)
final notificationServiceProvider =
    AutoDisposeProvider<NotificationService>.internal(
      notificationService,
      name: r'notificationServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationServiceRef = AutoDisposeProviderRef<NotificationService>;
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
String _$notificationStreamHash() =>
    r'f6e56a85d2b1868f9d8184e1c587ff36d13d02b3';

/// See also [notificationStream].
@ProviderFor(notificationStream)
final notificationStreamProvider =
    AutoDisposeStreamProvider<AppNotification>.internal(
      notificationStream,
      name: r'notificationStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationStreamRef = AutoDisposeStreamProviderRef<AppNotification>;
String _$notificationHistoryHash() =>
    r'5e77c6cc949f23e53f662cd9a1e7eb8255de7e71';

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
