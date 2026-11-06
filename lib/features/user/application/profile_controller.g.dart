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
        isAutoDispose: false,
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

String _$userRepositoryHash() => r'f0496e78a8e126603bd28e4db36c80d9407be556';

@ProviderFor(imagePicker)
final imagePickerProvider = ImagePickerProvider._();

final class ImagePickerProvider
    extends $FunctionalProvider<ImagePicker, ImagePicker, ImagePicker>
    with $Provider<ImagePicker> {
  ImagePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imagePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imagePickerHash();

  @$internal
  @override
  $ProviderElement<ImagePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImagePicker create(Ref ref) {
    return imagePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImagePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImagePicker>(value),
    );
  }
}

String _$imagePickerHash() => r'be60667b04027cd2a7d2e1b728a5c03b1bda8dc1';

@ProviderFor(cloudinaryService)
final cloudinaryServiceProvider = CloudinaryServiceProvider._();

final class CloudinaryServiceProvider
    extends
        $FunctionalProvider<
          CloudinaryService,
          CloudinaryService,
          CloudinaryService
        >
    with $Provider<CloudinaryService> {
  CloudinaryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudinaryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudinaryServiceHash();

  @$internal
  @override
  $ProviderElement<CloudinaryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CloudinaryService create(Ref ref) {
    return cloudinaryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudinaryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudinaryService>(value),
    );
  }
}

String _$cloudinaryServiceHash() => r'7d383b4f10a7b6135a5239313b14bb3a354d3a8b';

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

String _$userProfileHash() => r'1aafe6225c51b0409873f0fb7c44d63420ce2483';

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

String _$referralStatsHash() => r'266a4df810350a7511645cca31104dfed4a43686';

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
    r'7edb0553abef46ef451ec2a5d739b63744e06b2a';

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

String _$profileControllerHash() => r'3959613fb716422a348be551028ee01d12994613';

abstract class _$ProfileController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
