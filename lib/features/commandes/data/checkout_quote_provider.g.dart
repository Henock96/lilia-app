// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkout_quote_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Devis serveur du panier courant (F3-11) — `POST /orders/quote`.
///
/// Recalculé à chaque changement du panier (il est observé) et de chaque
/// entrée du checkout (paramètres de la famille). Le récapitulatif l'affiche
/// dès qu'il est là ; le checkout renvoie l'offre qu'il annonçait.

@ProviderFor(checkoutQuote)
final checkoutQuoteProvider = CheckoutQuoteFamily._();

/// Devis serveur du panier courant (F3-11) — `POST /orders/quote`.
///
/// Recalculé à chaque changement du panier (il est observé) et de chaque
/// entrée du checkout (paramètres de la famille). Le récapitulatif l'affiche
/// dès qu'il est là ; le checkout renvoie l'offre qu'il annonçait.

final class CheckoutQuoteProvider
    extends
        $FunctionalProvider<
          AsyncValue<CheckoutQuote>,
          CheckoutQuote,
          FutureOr<CheckoutQuote>
        >
    with $FutureModifier<CheckoutQuote>, $FutureProvider<CheckoutQuote> {
  /// Devis serveur du panier courant (F3-11) — `POST /orders/quote`.
  ///
  /// Recalculé à chaque changement du panier (il est observé) et de chaque
  /// entrée du checkout (paramètres de la famille). Le récapitulatif l'affiche
  /// dès qu'il est là ; le checkout renvoie l'offre qu'il annonçait.
  CheckoutQuoteProvider._({
    required CheckoutQuoteFamily super.from,
    required ({
      bool isDelivery,
      String? adresseId,
      String? quartierId,
      String? promoCode,
      bool useLoyaltyPoints,
      DateTime? scheduledFor,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'checkoutQuoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$checkoutQuoteHash();

  @override
  String toString() {
    return r'checkoutQuoteProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<CheckoutQuote> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CheckoutQuote> create(Ref ref) {
    final argument =
        this.argument
            as ({
              bool isDelivery,
              String? adresseId,
              String? quartierId,
              String? promoCode,
              bool useLoyaltyPoints,
              DateTime? scheduledFor,
            });
    return checkoutQuote(
      ref,
      isDelivery: argument.isDelivery,
      adresseId: argument.adresseId,
      quartierId: argument.quartierId,
      promoCode: argument.promoCode,
      useLoyaltyPoints: argument.useLoyaltyPoints,
      scheduledFor: argument.scheduledFor,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CheckoutQuoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$checkoutQuoteHash() => r'76788522ca3bad08478b1f605f8ac12098f0a2ee';

/// Devis serveur du panier courant (F3-11) — `POST /orders/quote`.
///
/// Recalculé à chaque changement du panier (il est observé) et de chaque
/// entrée du checkout (paramètres de la famille). Le récapitulatif l'affiche
/// dès qu'il est là ; le checkout renvoie l'offre qu'il annonçait.

final class CheckoutQuoteFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CheckoutQuote>,
          ({
            bool isDelivery,
            String? adresseId,
            String? quartierId,
            String? promoCode,
            bool useLoyaltyPoints,
            DateTime? scheduledFor,
          })
        > {
  CheckoutQuoteFamily._()
    : super(
        retry: null,
        name: r'checkoutQuoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Devis serveur du panier courant (F3-11) — `POST /orders/quote`.
  ///
  /// Recalculé à chaque changement du panier (il est observé) et de chaque
  /// entrée du checkout (paramètres de la famille). Le récapitulatif l'affiche
  /// dès qu'il est là ; le checkout renvoie l'offre qu'il annonçait.

  CheckoutQuoteProvider call({
    required bool isDelivery,
    String? adresseId,
    String? quartierId,
    String? promoCode,
    bool useLoyaltyPoints = false,
    DateTime? scheduledFor,
  }) => CheckoutQuoteProvider._(
    argument: (
      isDelivery: isDelivery,
      adresseId: adresseId,
      quartierId: quartierId,
      promoCode: promoCode,
      useLoyaltyPoints: useLoyaltyPoints,
      scheduledFor: scheduledFor,
    ),
    from: this,
  );

  @override
  String toString() => r'checkoutQuoteProvider';
}
