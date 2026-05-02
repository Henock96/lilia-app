// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userRepository)
final userRepositoryProvider = UserRepositoryProvider._();

final class UserRepositoryProvider
    extends $FunctionalProvider<UserRepository, UserRepository, UserRepository>
    with $Provider<UserRepository> {
  UserRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userRepositoryHash();

  @$internal
  @override
  $ProviderElement<UserRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserRepository create(Ref ref) {
    return userRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRepository>(value),
    );
  }
}

String _$userRepositoryHash() => r'8366fba5ac0d6b90c6a637882d24c5e759a5a92f';

@ProviderFor(userProfile)
final userProfileProvider = UserProfileProvider._();

final class UserProfileProvider
    extends $FunctionalProvider<AsyncValue<AppUser>, AppUser, FutureOr<AppUser>>
    with $FutureModifier<AppUser>, $FutureProvider<AppUser> {
  UserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userProfileHash();

  @$internal
  @override
  $FutureProviderElement<AppUser> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppUser> create(Ref ref) {
    return userProfile(ref);
  }
}

String _$userProfileHash() => r'a287223e5bef2dbd5a964cae13367afc78cb4598';

@ProviderFor(referralStats)
final referralStatsProvider = ReferralStatsProvider._();

final class ReferralStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReferralStats>,
          ReferralStats,
          FutureOr<ReferralStats>
        >
    with $FutureModifier<ReferralStats>, $FutureProvider<ReferralStats> {
  ReferralStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referralStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referralStatsHash();

  @$internal
  @override
  $FutureProviderElement<ReferralStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReferralStats> create(Ref ref) {
    return referralStats(ref);
  }
}

String _$referralStatsHash() => r'b43a16a60fc370140238a5c139249a19a19d8ec1';

@ProviderFor(loyaltyTransactions)
final loyaltyTransactionsProvider = LoyaltyTransactionsProvider._();

final class LoyaltyTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LoyaltyTransaction>>,
          List<LoyaltyTransaction>,
          FutureOr<List<LoyaltyTransaction>>
        >
    with
        $FutureModifier<List<LoyaltyTransaction>>,
        $FutureProvider<List<LoyaltyTransaction>> {
  LoyaltyTransactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loyaltyTransactionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loyaltyTransactionsHash();

  @$internal
  @override
  $FutureProviderElement<List<LoyaltyTransaction>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LoyaltyTransaction>> create(Ref ref) {
    return loyaltyTransactions(ref);
  }
}

String _$loyaltyTransactionsHash() =>
    r'12cdf338a8f8eecd0cbbe084f368c75f707af7da';

@ProviderFor(ProfileController)
final profileControllerProvider = ProfileControllerProvider._();

final class ProfileControllerProvider
    extends $AsyncNotifierProvider<ProfileController, void> {
  ProfileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileControllerHash();

  @$internal
  @override
  ProfileController create() => ProfileController();
}

String _$profileControllerHash() => r'791b2819b742e73ce7bce43950718c22e2aecf7f';

abstract class _$ProfileController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
