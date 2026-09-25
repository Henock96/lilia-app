// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claims_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// « Mes demandes » (F3-06).

@ProviderFor(myClaims)
final myClaimsProvider = MyClaimsProvider._();

/// « Mes demandes » (F3-06).

final class MyClaimsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClaimSummary>>,
          List<ClaimSummary>,
          FutureOr<List<ClaimSummary>>
        >
    with
        $FutureModifier<List<ClaimSummary>>,
        $FutureProvider<List<ClaimSummary>> {
  /// « Mes demandes » (F3-06).
  MyClaimsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myClaimsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myClaimsHash();

  @$internal
  @override
  $FutureProviderElement<List<ClaimSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClaimSummary>> create(Ref ref) {
    return myClaims(ref);
  }
}

String _$myClaimsHash() => r'92940038edf4160fa196df1d024af0158dfb5f59';

/// Une demande et son fil, relue toutes les 30 s tant que l'écran l'observe.

@ProviderFor(claimDetail)
final claimDetailProvider = ClaimDetailFamily._();

/// Une demande et son fil, relue toutes les 30 s tant que l'écran l'observe.

final class ClaimDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<ClaimDetail>,
          ClaimDetail,
          FutureOr<ClaimDetail>
        >
    with $FutureModifier<ClaimDetail>, $FutureProvider<ClaimDetail> {
  /// Une demande et son fil, relue toutes les 30 s tant que l'écran l'observe.
  ClaimDetailProvider._({
    required ClaimDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'claimDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$claimDetailHash();

  @override
  String toString() {
    return r'claimDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ClaimDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ClaimDetail> create(Ref ref) {
    final argument = this.argument as String;
    return claimDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ClaimDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$claimDetailHash() => r'a5c15100faadde3a602da1c882129384ddc22317';

/// Une demande et son fil, relue toutes les 30 s tant que l'écran l'observe.

final class ClaimDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ClaimDetail>, String> {
  ClaimDetailFamily._()
    : super(
        retry: null,
        name: r'claimDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Une demande et son fil, relue toutes les 30 s tant que l'écran l'observe.

  ClaimDetailProvider call(String claimId) =>
      ClaimDetailProvider._(argument: claimId, from: this);

  @override
  String toString() => r'claimDetailProvider';
}
