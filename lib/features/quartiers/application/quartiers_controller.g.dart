// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quartiers_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider pour la liste des quartiers (avec cache)

@ProviderFor(quartiersList)
final quartiersListProvider = QuartiersListProvider._();

/// Provider pour la liste des quartiers (avec cache)

final class QuartiersListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Quartier>>,
          List<Quartier>,
          FutureOr<List<Quartier>>
        >
    with $FutureModifier<List<Quartier>>, $FutureProvider<List<Quartier>> {
  /// Provider pour la liste des quartiers (avec cache)
  QuartiersListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quartiersListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quartiersListHash();

  @$internal
  @override
  $FutureProviderElement<List<Quartier>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Quartier>> create(Ref ref) {
    return quartiersList(ref);
  }
}

String _$quartiersListHash() => r'6f3705c96c7824dd653654623a86ccf1057e3cc8';

/// Provider pour calculer les frais de livraison

@ProviderFor(deliveryFee)
final deliveryFeeProvider = DeliveryFeeFamily._();

/// Provider pour calculer les frais de livraison

final class DeliveryFeeProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeliveryFeeResult>,
          DeliveryFeeResult,
          FutureOr<DeliveryFeeResult>
        >
    with
        $FutureModifier<DeliveryFeeResult>,
        $FutureProvider<DeliveryFeeResult> {
  /// Provider pour calculer les frais de livraison
  DeliveryFeeProvider._({
    required DeliveryFeeFamily super.from,
    required ({String restaurantId, String quartierId}) super.argument,
  }) : super(
         retry: null,
         name: r'deliveryFeeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$deliveryFeeHash();

  @override
  String toString() {
    return r'deliveryFeeProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<DeliveryFeeResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeliveryFeeResult> create(Ref ref) {
    final argument =
        this.argument as ({String restaurantId, String quartierId});
    return deliveryFee(
      ref,
      restaurantId: argument.restaurantId,
      quartierId: argument.quartierId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DeliveryFeeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$deliveryFeeHash() => r'e3524f78952cb0e2a9586fc401df230201f4acb9';

/// Provider pour calculer les frais de livraison

final class DeliveryFeeFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<DeliveryFeeResult>,
          ({String restaurantId, String quartierId})
        > {
  DeliveryFeeFamily._()
    : super(
        retry: null,
        name: r'deliveryFeeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour calculer les frais de livraison

  DeliveryFeeProvider call({
    required String restaurantId,
    required String quartierId,
  }) => DeliveryFeeProvider._(
    argument: (restaurantId: restaurantId, quartierId: quartierId),
    from: this,
  );

  @override
  String toString() => r'deliveryFeeProvider';
}
