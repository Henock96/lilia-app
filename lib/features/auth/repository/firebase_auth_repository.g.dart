// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_auth_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authRepositoryHash() => r'463009a95d2d294e423349aca58d846e4c9c8d9b';

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
