// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fils d'Ariane Sentry **et** garde de session.
///
/// L'observateur est le seul endroit traversé par *toutes* les erreurs d'API,
/// quel que soit le dépôt appelant : c'est donc là que le 401 doit être vu.
/// Avant, `ApiErrorKind.unauthorized` était calculé puis lu par deux dépôts
/// pour des replis locaux, et la session expirée n'était traitée nulle part.

@ProviderFor(networkObserver)
final networkObserverProvider = NetworkObserverProvider._();

/// Fils d'Ariane Sentry **et** garde de session.
///
/// L'observateur est le seul endroit traversé par *toutes* les erreurs d'API,
/// quel que soit le dépôt appelant : c'est donc là que le 401 doit être vu.
/// Avant, `ApiErrorKind.unauthorized` était calculé puis lu par deux dépôts
/// pour des replis locaux, et la session expirée n'était traitée nulle part.

final class NetworkObserverProvider
    extends
        $FunctionalProvider<NetworkObserver, NetworkObserver, NetworkObserver>
    with $Provider<NetworkObserver> {
  /// Fils d'Ariane Sentry **et** garde de session.
  ///
  /// L'observateur est le seul endroit traversé par *toutes* les erreurs d'API,
  /// quel que soit le dépôt appelant : c'est donc là que le 401 doit être vu.
  /// Avant, `ApiErrorKind.unauthorized` était calculé puis lu par deux dépôts
  /// pour des replis locaux, et la session expirée n'était traitée nulle part.
  NetworkObserverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkObserverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkObserverHash();

  @$internal
  @override
  $ProviderElement<NetworkObserver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkObserver create(Ref ref) {
    return networkObserver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkObserver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkObserver>(value),
    );
  }
}

String _$networkObserverHash() => r'3ef4b3f9876c30fc96b55158373c586201e123d0';

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

final class ApiClientProvider
    extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientHash() => r'4ae7a13907308085d9684c6d049fadd8917d387f';
