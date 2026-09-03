// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_status_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Suit un paiement jusqu'à son issue.
///
/// **Deux sources concourantes, et c'est voulu** :
///  · l'interrogation périodique de `GET /payments/:id/status` ;
///  · le push FCM `payment_confirmed` / `payment_failed`, qui arrive
///    généralement avant l'interrogation suivante.
///
/// La première qui tranche gagne ; le serveur étant la seule autorité, les deux
/// disent la même chose. Le polling seul suffirait, mais il ferait attendre le
/// client jusqu'à trois secondes de plus sur une 4G lente.
///
/// **Cadence** : 3 s pendant la première minute (le client compose son code),
/// puis 5 s. Au-delà de trois minutes on s'arrête sur `undetermined` — continuer
/// consommerait sa data sans rien apprendre, et le webhook tranchera de son côté.

@ProviderFor(PaymentStatusController)
final paymentStatusControllerProvider = PaymentStatusControllerFamily._();

/// Suit un paiement jusqu'à son issue.
///
/// **Deux sources concourantes, et c'est voulu** :
///  · l'interrogation périodique de `GET /payments/:id/status` ;
///  · le push FCM `payment_confirmed` / `payment_failed`, qui arrive
///    généralement avant l'interrogation suivante.
///
/// La première qui tranche gagne ; le serveur étant la seule autorité, les deux
/// disent la même chose. Le polling seul suffirait, mais il ferait attendre le
/// client jusqu'à trois secondes de plus sur une 4G lente.
///
/// **Cadence** : 3 s pendant la première minute (le client compose son code),
/// puis 5 s. Au-delà de trois minutes on s'arrête sur `undetermined` — continuer
/// consommerait sa data sans rien apprendre, et le webhook tranchera de son côté.
final class PaymentStatusControllerProvider
    extends $NotifierProvider<PaymentStatusController, PaymentWaitState> {
  /// Suit un paiement jusqu'à son issue.
  ///
  /// **Deux sources concourantes, et c'est voulu** :
  ///  · l'interrogation périodique de `GET /payments/:id/status` ;
  ///  · le push FCM `payment_confirmed` / `payment_failed`, qui arrive
  ///    généralement avant l'interrogation suivante.
  ///
  /// La première qui tranche gagne ; le serveur étant la seule autorité, les deux
  /// disent la même chose. Le polling seul suffirait, mais il ferait attendre le
  /// client jusqu'à trois secondes de plus sur une 4G lente.
  ///
  /// **Cadence** : 3 s pendant la première minute (le client compose son code),
  /// puis 5 s. Au-delà de trois minutes on s'arrête sur `undetermined` — continuer
  /// consommerait sa data sans rien apprendre, et le webhook tranchera de son côté.
  PaymentStatusControllerProvider._({
    required PaymentStatusControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'paymentStatusControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paymentStatusControllerHash();

  @override
  String toString() {
    return r'paymentStatusControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PaymentStatusController create() => PaymentStatusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentWaitState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentWaitState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PaymentStatusControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paymentStatusControllerHash() =>
    r'94b3b4d98d81f60c127b139c8971ccab48fde422';

/// Suit un paiement jusqu'à son issue.
///
/// **Deux sources concourantes, et c'est voulu** :
///  · l'interrogation périodique de `GET /payments/:id/status` ;
///  · le push FCM `payment_confirmed` / `payment_failed`, qui arrive
///    généralement avant l'interrogation suivante.
///
/// La première qui tranche gagne ; le serveur étant la seule autorité, les deux
/// disent la même chose. Le polling seul suffirait, mais il ferait attendre le
/// client jusqu'à trois secondes de plus sur une 4G lente.
///
/// **Cadence** : 3 s pendant la première minute (le client compose son code),
/// puis 5 s. Au-delà de trois minutes on s'arrête sur `undetermined` — continuer
/// consommerait sa data sans rien apprendre, et le webhook tranchera de son côté.

final class PaymentStatusControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PaymentStatusController,
          PaymentWaitState,
          PaymentWaitState,
          PaymentWaitState,
          String
        > {
  PaymentStatusControllerFamily._()
    : super(
        retry: null,
        name: r'paymentStatusControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Suit un paiement jusqu'à son issue.
  ///
  /// **Deux sources concourantes, et c'est voulu** :
  ///  · l'interrogation périodique de `GET /payments/:id/status` ;
  ///  · le push FCM `payment_confirmed` / `payment_failed`, qui arrive
  ///    généralement avant l'interrogation suivante.
  ///
  /// La première qui tranche gagne ; le serveur étant la seule autorité, les deux
  /// disent la même chose. Le polling seul suffirait, mais il ferait attendre le
  /// client jusqu'à trois secondes de plus sur une 4G lente.
  ///
  /// **Cadence** : 3 s pendant la première minute (le client compose son code),
  /// puis 5 s. Au-delà de trois minutes on s'arrête sur `undetermined` — continuer
  /// consommerait sa data sans rien apprendre, et le webhook tranchera de son côté.

  PaymentStatusControllerProvider call(String paymentId) =>
      PaymentStatusControllerProvider._(argument: paymentId, from: this);

  @override
  String toString() => r'paymentStatusControllerProvider';
}

/// Suit un paiement jusqu'à son issue.
///
/// **Deux sources concourantes, et c'est voulu** :
///  · l'interrogation périodique de `GET /payments/:id/status` ;
///  · le push FCM `payment_confirmed` / `payment_failed`, qui arrive
///    généralement avant l'interrogation suivante.
///
/// La première qui tranche gagne ; le serveur étant la seule autorité, les deux
/// disent la même chose. Le polling seul suffirait, mais il ferait attendre le
/// client jusqu'à trois secondes de plus sur une 4G lente.
///
/// **Cadence** : 3 s pendant la première minute (le client compose son code),
/// puis 5 s. Au-delà de trois minutes on s'arrête sur `undetermined` — continuer
/// consommerait sa data sans rien apprendre, et le webhook tranchera de son côté.

abstract class _$PaymentStatusController extends $Notifier<PaymentWaitState> {
  late final _$args = ref.$arg as String;
  String get paymentId => _$args;

  PaymentWaitState build(String paymentId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PaymentWaitState, PaymentWaitState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PaymentWaitState, PaymentWaitState>,
              PaymentWaitState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Dernière tentative d'encaissement d'une commande, ou `null`.
///
/// Sert à une seule chose, mais elle est importante : savoir si un paiement est
/// **déjà en cours** avant de proposer « Payer maintenant ». Sans cette
/// information, l'écran de commande offrait une reprise pendant qu'une demande
/// attendait sur le téléphone du client — le geste exact qui invite au double
/// paiement.
///
/// Lecture pure, non rafraîchie automatiquement : l'écran d'attente s'occupe du
/// suivi actif. Ici, on veut l'état au moment où le client regarde sa commande.

@ProviderFor(orderPayment)
final orderPaymentProvider = OrderPaymentFamily._();

/// Dernière tentative d'encaissement d'une commande, ou `null`.
///
/// Sert à une seule chose, mais elle est importante : savoir si un paiement est
/// **déjà en cours** avant de proposer « Payer maintenant ». Sans cette
/// information, l'écran de commande offrait une reprise pendant qu'une demande
/// attendait sur le téléphone du client — le geste exact qui invite au double
/// paiement.
///
/// Lecture pure, non rafraîchie automatiquement : l'écran d'attente s'occupe du
/// suivi actif. Ici, on veut l'état au moment où le client regarde sa commande.

final class OrderPaymentProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaymentStatusResponse?>,
          PaymentStatusResponse?,
          FutureOr<PaymentStatusResponse?>
        >
    with
        $FutureModifier<PaymentStatusResponse?>,
        $FutureProvider<PaymentStatusResponse?> {
  /// Dernière tentative d'encaissement d'une commande, ou `null`.
  ///
  /// Sert à une seule chose, mais elle est importante : savoir si un paiement est
  /// **déjà en cours** avant de proposer « Payer maintenant ». Sans cette
  /// information, l'écran de commande offrait une reprise pendant qu'une demande
  /// attendait sur le téléphone du client — le geste exact qui invite au double
  /// paiement.
  ///
  /// Lecture pure, non rafraîchie automatiquement : l'écran d'attente s'occupe du
  /// suivi actif. Ici, on veut l'état au moment où le client regarde sa commande.
  OrderPaymentProvider._({
    required OrderPaymentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'orderPaymentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$orderPaymentHash();

  @override
  String toString() {
    return r'orderPaymentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PaymentStatusResponse?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaymentStatusResponse?> create(Ref ref) {
    final argument = this.argument as String;
    return orderPayment(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OrderPaymentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$orderPaymentHash() => r'69d15d55b4a5717639191c0b8580a13e984e9961';

/// Dernière tentative d'encaissement d'une commande, ou `null`.
///
/// Sert à une seule chose, mais elle est importante : savoir si un paiement est
/// **déjà en cours** avant de proposer « Payer maintenant ». Sans cette
/// information, l'écran de commande offrait une reprise pendant qu'une demande
/// attendait sur le téléphone du client — le geste exact qui invite au double
/// paiement.
///
/// Lecture pure, non rafraîchie automatiquement : l'écran d'attente s'occupe du
/// suivi actif. Ici, on veut l'état au moment où le client regarde sa commande.

final class OrderPaymentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PaymentStatusResponse?>, String> {
  OrderPaymentFamily._()
    : super(
        retry: null,
        name: r'orderPaymentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Dernière tentative d'encaissement d'une commande, ou `null`.
  ///
  /// Sert à une seule chose, mais elle est importante : savoir si un paiement est
  /// **déjà en cours** avant de proposer « Payer maintenant ». Sans cette
  /// information, l'écran de commande offrait une reprise pendant qu'une demande
  /// attendait sur le téléphone du client — le geste exact qui invite au double
  /// paiement.
  ///
  /// Lecture pure, non rafraîchie automatiquement : l'écran d'attente s'occupe du
  /// suivi actif. Ici, on veut l'état au moment où le client regarde sa commande.

  OrderPaymentProvider call(String orderId) =>
      OrderPaymentProvider._(argument: orderId, from: this);

  @override
  String toString() => r'orderPaymentProvider';
}
