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
    required ({String restaurantId, String quartierId, int? subTotal})
    super.argument,
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
        this.argument
            as ({String restaurantId, String quartierId, int? subTotal});
    return deliveryFee(
      ref,
      restaurantId: argument.restaurantId,
      quartierId: argument.quartierId,
      subTotal: argument.subTotal,
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

String _$deliveryFeeHash() => r'3d321e64da25eb0cd9207efed98fbc3fd53d44f4';

/// Provider pour calculer les frais de livraison

final class DeliveryFeeFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<DeliveryFeeResult>,
          ({String restaurantId, String quartierId, int? subTotal})
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
    int? subTotal,
  }) => DeliveryFeeProvider._(
    argument: (
      restaurantId: restaurantId,
      quartierId: quartierId,
      subTotal: subTotal,
    ),
    from: this,
  );

  @override
  String toString() => r'deliveryFeeProvider';
}
