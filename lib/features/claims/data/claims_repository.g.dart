// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claims_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Réclamations du client (F3-06) — `/orders/:id/claims`, `/me/claims`,
/// `/claims/:id`.

@ProviderFor(claimsRepository)
final claimsRepositoryProvider = ClaimsRepositoryProvider._();

/// Réclamations du client (F3-06) — `/orders/:id/claims`, `/me/claims`,
/// `/claims/:id`.

final class ClaimsRepositoryProvider
    extends
        $FunctionalProvider<
          ClaimsRepository,
          ClaimsRepository,
          ClaimsRepository
        >
    with $Provider<ClaimsRepository> {
  /// Réclamations du client (F3-06) — `/orders/:id/claims`, `/me/claims`,
  /// `/claims/:id`.
  ClaimsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'claimsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$claimsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ClaimsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClaimsRepository create(Ref ref) {
    return claimsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClaimsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClaimsRepository>(value),
    );
  }
}

String _$claimsRepositoryHash() => r'20acce2b17fb2b6cb3401a6e94c387eba221fbb1';
