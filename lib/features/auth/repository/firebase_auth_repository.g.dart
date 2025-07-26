// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_auth_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$httpClientHash() => r'e3f3e796ea46a17320ed4152466f2e23c3638fe5';

/// See also [httpClient].
@ProviderFor(httpClient)
final httpClientProvider = Provider<http.Client>.internal(
  httpClient,
  name: r'httpClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$httpClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HttpClientRef = ProviderRef<http.Client>;
String _$authRepositoryHash() => r'40fb13f3d0ae30ab5ceeefd1c8e306e2330f8958';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider =
    Provider<FirebaseAuthenticationRepository>.internal(
      authRepository,
      name: r'authRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = ProviderRef<FirebaseAuthenticationRepository>;
String _$firebaseAuthHash() => r'46c40b7c5cf8ab936c0daa96a6af106bd2ae5d51';

/// See also [firebaseAuth].
@ProviderFor(firebaseAuth)
final firebaseAuthProvider = Provider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firebaseAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthRef = ProviderRef<FirebaseAuth>;
String _$googleSignInHash() => r'33e2d830c18590dbfdef7f4796eb1120b7e87104';

/// See also [googleSignIn].
@ProviderFor(googleSignIn)
final googleSignInProvider = Provider<GoogleSignIn>.internal(
  googleSignIn,
  name: r'googleSignInProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$googleSignInHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GoogleSignInRef = ProviderRef<GoogleSignIn>;
String _$authStateChangeHash() => r'f7c1451f0aab7c8bac41bcff2c4e22aeb936cb24';

/// See also [authStateChange].
@ProviderFor(authStateChange)
final authStateChangeProvider = StreamProvider<AppUser?>.internal(
  authStateChange,
  name: r'authStateChangeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authStateChangeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateChangeRef = StreamProviderRef<AppUser?>;
String _$firebaseIdTokenHash() => r'5dc557dc5d74b06f4192776187b0b6dbd9ec95a5';

/// See also [firebaseIdToken].
@ProviderFor(firebaseIdToken)
final firebaseIdTokenProvider = StreamProvider<String?>.internal(
  firebaseIdToken,
  name: r'firebaseIdTokenProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firebaseIdTokenHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseIdTokenRef = StreamProviderRef<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
