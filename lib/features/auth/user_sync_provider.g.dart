// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserDataSynchronizer)
final userDataSynchronizerProvider = UserDataSynchronizerProvider._();

final class UserDataSynchronizerProvider
    extends $AsyncNotifierProvider<UserDataSynchronizer, void> {
  UserDataSynchronizerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDataSynchronizerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDataSynchronizerHash();

  @$internal
  @override
  UserDataSynchronizer create() => UserDataSynchronizer();
}

String _$userDataSynchronizerHash() =>
    r'3beef7efd05d692959873e7b9cd7b93a6e7e31b7';

abstract class _$UserDataSynchronizer extends $AsyncNotifier<void> {
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
