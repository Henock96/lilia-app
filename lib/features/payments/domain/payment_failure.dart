import 'package:lilia_app/features/payments/data/payment_service.dart';

/// Issue d'un paiement **du point de vue du client**, distincte du statut
/// technique renvoyé par le serveur.
///
/// Le backend n'a que quatre statuts (`PENDING`, `SUCCESS`, `FAILED`,
/// `CANCELLED`) parce qu'ils décrivent une ligne comptable. Le client, lui, a
/// besoin de distinguer des situations que ces quatre-là confondent : un
/// paiement qu'il a refusé sur son téléphone n'appelle pas le même écran qu'un
/// paiement que l'opérateur n'a jamais confirmé.
///
/// ⚠️ Ces valeurs sont **dérivées** du statut serveur et du code d'échec ; elles
/// ne sont jamais stockées ni renvoyées au serveur. La source de vérité reste le
/// backend.
enum PaymentOutcome {
  /// En cours chez l'opérateur. **Jamais présenté comme un échec.**
  pending,

  succeeded,

  /// Refusé pour une raison connue ou non. Une reprise a du sens.
  failed,

  /// Abandonné : le client a refusé la demande, ou un administrateur a rejeté
  /// le virement. Ce n'est pas une erreur du système, et le dire ainsi évite
  /// d'inquiéter pour rien.
  cancelled,

  /// Le délai est dépassé sans que l'opérateur ait tranché.
  expired,

  /// L'issue n'est pas connue **pour l'instant**. Ce n'est pas un échec : le
  /// paiement peut encore aboutir, confirmé par le webhook ou le cron.
  unknown,
}

/// Ce qu'on montre au client — et rien d'autre.
class PaymentUserMessage {
  const PaymentUserMessage({
    required this.title,
    required this.body,
    required this.canRetry,
  });

  final String title;
  final String body;

  /// Une reprise a-t-elle du sens ? `false` tant que l'issue n'est pas
  /// tranchée : proposer « Réessayer » sur un paiement encore en cours est la
  /// manière la plus directe de provoquer un double débit.
  final bool canRetry;
}

/// Traduit un échec technique en message client.
///
/// ## Pourquoi cette couche existe
///
/// `Payment.failureMessage` porte le texte **brut de l'opérateur**. Un client a
/// réellement lu, dans une notification :
///
/// ```
/// "Airtel_CG" did not specify a reason for this faliure
/// ```
///
/// — faute d'orthographe comprise. Le champ était consommé en croyant qu'il
/// avait été rédigé pour le client ; personne ne le réécrivait.
///
/// ## Les deux règles
///
/// 1. **On traduit depuis le `failureCode`, jamais depuis le `failureMessage`.**
///    Le code est une valeur stable et énumérée ; le message est du texte libre,
///    rédigé par un opérateur, dans une langue et un ton qu'on ne contrôle pas.
///
/// 2. **On n'invente jamais une cause.** `UNSPECIFIED_FAILURE` est documenté par
///    pawaPay comme « l'opérateur a confirmé l'échec sans en donner la raison ».
///    Afficher « solde insuffisant » dans ce cas serait une supposition — et
///    envoyer un client vérifier un solde qui n'a rien à voir.
///
/// Le `failureMessage` reste disponible pour les journaux et le support ; il ne
/// doit simplement jamais atteindre l'écran.
PaymentUserMessage mapPaymentFailure({
  required PaymentStatus status,
  String? failureCode,
}) {
  if (status == PaymentStatus.success) {
    return const PaymentUserMessage(
      title: 'Paiement confirmé',
      body: 'Votre commande a été confirmée et transmise au vendeur.',
      canRetry: false,
    );
  }

  if (status == PaymentStatus.pending) {
    return const PaymentUserMessage(
      title: 'Paiement en cours',
      body:
          'Nous vérifions votre paiement. Cela peut prendre quelques instants. '
          'Ne relancez pas le paiement pendant la vérification.',
      canRetry: false,
    );
  }

  final code = failureCode?.trim().toUpperCase();

  switch (code) {
    // ── Abandons : ni panne, ni erreur ────────────────────────────────────
    case 'PAYMENT_NOT_APPROVED':
      return const PaymentUserMessage(
        title: 'Paiement annulé',
        body:
            'La demande n’a pas été validée sur votre téléphone. '
            'Votre commande n’a pas été confirmée.',
        canRetry: true,
      );
    case 'MANUALLY_CANCELLED':
      return const PaymentUserMessage(
        title: 'Paiement annulé',
        body: 'Le paiement a été annulé. Votre commande n’a pas été confirmée.',
        canRetry: true,
      );
    case 'ADMIN_REJECTED':
      return const PaymentUserMessage(
        title: 'Paiement non retrouvé',
        body:
            'Nous n’avons pas retrouvé votre virement. Si vous l’avez bien '
            'effectué, contactez-nous — sinon, vous pouvez réessayer.',
        canRetry: true,
      );

    // ── Délai dépassé ─────────────────────────────────────────────────────
    case 'RECONCILIATION_TIMEOUT':
      return const PaymentUserMessage(
        title: 'Le paiement a expiré',
        body:
            'Le délai de paiement est dépassé. Vous pouvez relancer le paiement '
            'pour confirmer votre commande.',
        canRetry: true,
      );

    // ── Causes précises, et seulement quand elles le sont vraiment ────────
    case 'INSUFFICIENT_BALANCE':
      return const PaymentUserMessage(
        title: 'Solde insuffisant',
        body:
            'Le solde de votre compte Mobile Money ne couvre pas ce paiement. '
            'Rechargez-le, puis réessayez.',
        canRetry: true,
      );
    case 'PAYER_LIMIT_REACHED':
    case 'WALLET_LIMIT_REACHED':
      return const PaymentUserMessage(
        title: 'Plafond atteint',
        body:
            'Le plafond de votre compte Mobile Money est atteint. '
            'Réessayez plus tard ou utilisez un autre numéro.',
        canRetry: true,
      );
    case 'PAYER_NOT_FOUND':
    case 'RECIPIENT_NOT_FOUND':
    case 'INVALID_PHONE_NUMBER':
      return const PaymentUserMessage(
        title: 'Numéro incorrect',
        body:
            'Ce numéro ne correspond pas à un compte Mobile Money actif. '
            'Vérifiez-le, puis réessayez.',
        canRetry: true,
      );
    case 'PROVIDER_TEMPORARILY_UNAVAILABLE':
    case 'PAYMENT_PROVIDER_UNAVAILABLE':
      return const PaymentUserMessage(
        title: 'Service indisponible',
        body:
            'Le service de paiement Mobile Money est momentanément '
            'indisponible. Réessayez dans quelques instants.',
        canRetry: true,
      );

    // ── L'opérateur n'a pas dit pourquoi ──────────────────────────────────
    //
    // C'est le cas le plus fréquent, et celui qui a motivé cette couche.
    // `UNSPECIFIED_FAILURE` signifie littéralement « échec confirmé, raison
    // non communiquée » : on ne peut rien affirmer de plus.
    default:
      return const PaymentUserMessage(
        title: 'Paiement non abouti',
        body:
            'Le paiement n’a pas pu être finalisé. Aucun montant n’a été '
            'prélevé pour cette commande. Vous pouvez réessayer dans quelques '
            'instants.',
        canRetry: true,
      );
  }
}

/// Issue client déduite du statut serveur et du code d'échec.
///
/// `PaymentStatus.cancelled` côté serveur recouvre deux choses : le refus du
/// client sur son téléphone et le rejet d'un virement par un administrateur.
/// Les deux se disent « annulé » au client, mais pas avec les mêmes mots — d'où
/// la distinction faite dans [mapPaymentFailure] et non ici.
PaymentOutcome outcomeOf({
  required PaymentStatus status,
  String? failureCode,
}) {
  switch (status) {
    case PaymentStatus.success:
      return PaymentOutcome.succeeded;
    case PaymentStatus.pending:
      return PaymentOutcome.pending;
    case PaymentStatus.cancelled:
      return PaymentOutcome.cancelled;
    case PaymentStatus.failed:
      final code = failureCode?.trim().toUpperCase();
      if (code == 'RECONCILIATION_TIMEOUT') return PaymentOutcome.expired;
      if (code == 'PAYMENT_NOT_APPROVED' || code == 'MANUALLY_CANCELLED') {
        return PaymentOutcome.cancelled;
      }
      return PaymentOutcome.failed;
  }
}
