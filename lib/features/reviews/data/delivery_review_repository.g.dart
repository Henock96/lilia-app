// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_review_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deliveryReviewRepository)
final deliveryReviewRepositoryProvider = DeliveryReviewRepositoryProvider._();

final class DeliveryReviewRepositoryProvider
    extends
        $FunctionalProvider<
          DeliveryReviewRepository,
          DeliveryReviewRepository,
          DeliveryReviewRepository
        >
    with $Provider<DeliveryReviewRepository> {
  DeliveryReviewRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deliveryReviewRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deliveryReviewRepositoryHash();

  @$internal
  @override
  $ProviderElement<DeliveryReviewRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeliveryReviewRepository create(Ref ref) {
    return deliveryReviewRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeliveryReviewRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeliveryReviewRepository>(value),
    );
  }
}

String _$deliveryReviewRepositoryHash() =>
    r'c85fd59333dd05982105869567c463696cee8ed2';
