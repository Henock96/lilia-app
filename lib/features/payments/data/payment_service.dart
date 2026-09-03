import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';

enum PaymentStatus { pending, success, failed, cancelled }

/// Instructions de virement renvoyées par le backend en mode MANUAL.
///
/// Ces valeurs font autorité : le numéro d'encaissement et le montant à envoyer
/// viennent du serveur (`LILIA_PAYMENT_PHONE` / `LILIA_AIRTEL_PAYMENT_PHONE` et
/// `order.total`). L'app les affichait auparavant depuis des constantes en dur —
/// dont un numéro Airtel qui n'était qu'un placeholder — et changer le numéro
/// d'encaissement imposait une release sur les stores.
class PaymentInstructions {
  final String phone;
  final double amount;
  final String reference;
  final String methodLabel;
  final String message;
  final String? note;

  const PaymentInstructions({
    required this.phone,
    required this.amount,
    required this.reference,
    required this.methodLabel,
    required this.message,
    this.note,
  });

  factory PaymentInstructions.fromJson(Map<String, dynamic> json) {
    return PaymentInstructions(
      phone: json['phone'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reference: json['reference'] as String? ?? '',
      methodLabel: json['methodLabel'] as String? ?? 'Mobile Money',
      message: json['message'] as String? ?? '',
      note: json['note'] as String?,
    );
  }
}

class PaymentResponse {
  final String paymentId;
  final String referenceId;
  final String message;

  /// Mode d'encaissement du serveur : `PAWAPAY`, `MANUAL`, `ZERO_AMOUNT`…
  ///
  /// C'est lui qui décide de l'écran suivant — une modale d'instructions de
  /// virement (MANUAL) ou un écran d'attente (PAWAPAY). L'application ne le
  /// devine pas : basculer de mode côté serveur ne doit pas exiger une release.
  final String mode;

  /// Montant réellement dû, tel que le serveur l'a calculé.
  final int amount;
  final String currency;

  /// Statut initial — toujours `PENDING`, sauf commande réglée en points.
  final String status;

  /// Délai conseillé avant la première interrogation de statut.
  final int pollAfterMs;

  /// Présent uniquement en mode MANUAL.
  final PaymentInstructions? instructions;

  PaymentResponse({
    required this.paymentId,
    required this.referenceId,
    required this.message,
    required this.mode,
    required this.amount,
    required this.currency,
    required this.status,
    required this.pollAfterMs,
    this.instructions,
  });

  /// Le paiement se joue-t-il sur le téléphone du client (push USSD) ?
  bool get isInteractive => mode == 'PAWAPAY';

  /// Rien à payer : commande intégralement réglée en points de fidélité.
  bool get isSettled => status == 'SUCCESS';

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    // Trois formats selon PAYMENT_MODE :
    //  • PAWAPAY → { paymentId, status, mode, amount, pollAfterMs }
    //  • MANUAL  → { paymentId, mode, instructions: { reference, message, ... } }
    //  • MTN     → { paymentId, referenceId } (rail historique)
    final instructions = json['instructions'] as Map<String, dynamic>?;
    return PaymentResponse(
      paymentId: json['paymentId'] as String,
      referenceId:
          (json['referenceId'] ?? instructions?['reference']) as String? ?? '',
      message:
          (json['message'] ?? instructions?['message']) as String? ??
          'Paiement initié',
      mode: json['mode'] as String? ?? 'MANUAL',
      amount: (json['amount'] as num?)?.round() ??
          (instructions?['amount'] as num?)?.round() ??
          0,
      currency: json['currency'] as String? ?? 'XAF',
      status: json['status'] as String? ?? 'PENDING',
      pollAfterMs: (json['pollAfterMs'] as num?)?.toInt() ?? 3000,
      instructions: instructions != null
          ? PaymentInstructions.fromJson(instructions)
          : null,
    );
  }
}

class PaymentStatusResponse {
  final String paymentId;
  final PaymentStatus status;
  final String? financialTransactionId;
  final double? amount;
  final String? currency;
  final String? reason;

  /// Code d'échec technique du prestataire — jamais affiché tel quel.
  final String? failureCode;

  /// Motif **brut de l'opérateur** — journaux et support uniquement.
  ///
  /// ⚠️ Ce champ portait autrefois la mention « rédigé par le serveur, destiné
  /// au client ». C'était faux, et c'est cette phrase qui a fait afficher
  /// « "Airtel_CG" did not specify a reason for this faliure » à un client.
  /// Personne ne réécrit ce texte : il traverse pawaPay depuis l'opérateur.
  final String? failureMessage;

  PaymentStatusResponse({
    required this.paymentId,
    required this.status,
    this.financialTransactionId,
    this.amount,
    this.currency,
    this.reason,
    this.failureCode,
    this.failureMessage,
  });

  bool get isTerminal => status != PaymentStatus.pending;

  /// ⚠️ `displayFailure` a été **supprimé**.
  ///
  /// Il renvoyait `failureMessage` en supposant que le serveur l'avait rédigé
  /// pour le client. C'était faux : ce champ porte le texte **brut de
  /// l'opérateur**, que personne ne réécrit. Un client a réellement lu
  /// « "Airtel_CG" did not specify a reason for this faliure », faute
  /// d'orthographe comprise.
  ///
  /// Passer par `mapPaymentFailure(status:, failureCode:)`
  /// (`domain/payment_failure.dart`), qui traduit depuis le **code** — stable et
  /// énuméré — et n'invente jamais de cause quand l'opérateur n'en donne pas.
  ///
  /// `failureMessage` et `failureCode` restent exposés : ils appartiennent aux
  /// journaux et au support, pas à l'écran.

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      paymentId: json['paymentId'] as String,
      status: _parseStatus(json['status'] as String),
      financialTransactionId: json['financialTransactionId'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      reason: json['reason'] as String?,
      failureCode: json['failureCode'] as String?,
      failureMessage: json['failureMessage'] as String?,
    );
  }

  static PaymentStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return PaymentStatus.pending;
      case 'SUCCESS':
      case 'SUCCESSFUL':
        return PaymentStatus.success;
      case 'FAILED':
        return PaymentStatus.failed;
      case 'CANCELLED':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }
}

class PaymentService {
  final ApiClient _api;

  PaymentService({required ApiClient api}) : _api = api;

  // Créer un paiement
  /// Initie un paiement.
  ///
  /// ⚠️ **Aucun montant n'est envoyé.** Le serveur le calcule depuis
  /// `order.total` et ignore tout `amount` reçu (le champ a été retiré de son
  /// DTO). L'envoyer quand même entretenait l'illusion que le client pouvait
  /// influer dessus.
  ///
  /// [method] permet de viser un autre opérateur que celui choisi au checkout —
  /// le cas d'une seconde tentative quand le solde MTN est épuisé.
  Future<PaymentResponse> createPayment({
    required String orderId,
    required String phoneNumber,
    String? method,
    String? payerMessage,
  }) async {
    try {
      debugPrint('💳 Initiation du paiement — commande $orderId');

      final res = await _api.postJson(
        '/payments',
        body: {
          'orderId': orderId,
          'phoneNumber': phoneNumber,
          if (method != null) 'method': method,
          'payerMessage': payerMessage ?? 'Paiement commande $orderId',
        },
      );

      // Réponse enveloppée `{ data: {...} }` par l'interceptor backend.
      return PaymentResponse.fromJson(ApiResponse.mapOf(res.data));
    } catch (e) {
      debugPrint('❌ Error creating payment: $e');
      rethrow;
    }
  }

  // Vérifier le statut du paiement
  Future<PaymentStatusResponse> checkPaymentStatus(String paymentId) async {
    try {
      debugPrint('🔍 Checking payment status: $paymentId');

      final res = await _api.getJson('/payments/$paymentId/status');

      // Réponse enveloppée `{ data: {...} }` par l'interceptor backend.
      return PaymentStatusResponse.fromJson(ApiResponse.mapOf(res.data));
    } catch (e) {
      debugPrint('❌ Error checking payment status: $e');
      rethrow;
    }
  }

  /// Dernière tentative d'encaissement d'une commande, ou `null`.
  ///
  /// Lecture pure : elle ne crée rien et ne relance aucune demande chez
  /// l'opérateur. C'est ce qui permet à l'écran de commande de savoir qu'un
  /// paiement est **déjà en cours** avant de proposer « Payer maintenant ».
  ///
  /// Sans elle, il fallait rejouer `POST /payments` pour connaître l'état —
  /// une écriture, donc un risque de seconde sollicitation du téléphone du
  /// client, pour une simple question.
  Future<PaymentStatusResponse?> getPaymentForOrder(String orderId) async {
    try {
      final res = await _api.getJson('/payments/by-order/$orderId');
      final data = res.data;
      // `null` légitime : aucune tentative n'a encore été ouverte.
      if (data is Map && data['data'] == null) return null;
      return PaymentStatusResponse.fromJson(ApiResponse.mapOf(data));
    } catch (e) {
      // Ne jamais bloquer l'écran de commande sur cette lecture : à défaut
      // d'information, on retombe sur le comportement précédent (bouton
      // proposé), et le serveur reste le garde-fou contre le double débit.
      debugPrint('⚠️ Statut de paiement de la commande $orderId indisponible : $e');
      return null;
    }
  }

  // Polling du statut avec retry
  Future<PaymentStatusResponse> waitForPaymentCompletion({
    required String paymentId,
    Duration timeout = const Duration(minutes: 3),
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      try {
        final status = await checkPaymentStatus(paymentId);

        if (status.status == PaymentStatus.success ||
            status.status == PaymentStatus.failed ||
            status.status == PaymentStatus.cancelled) {
          return status;
        }

        debugPrint(
          '⏳ Payment still pending, checking again in ${pollInterval.inSeconds}s...',
        );
        await Future<void>.delayed(pollInterval);
      } catch (e) {
        debugPrint('⚠️ Error during polling: $e');
        await Future<void>.delayed(pollInterval);
      }
    }

    throw Exception('Payment verification timeout');
  }

  /// Numéro au format attendu par le backend : chiffres, indicatif 242 inclus.
  ///
  /// ⚠️ **Le zéro initial est CONSERVÉ.** Les mobiles congolais s'écrivent
  /// `06 XXX XX XX` — neuf chiffres dont le premier fait partie du numéro, et
  /// non un préfixe interurbain. En international : `242 06 XXX XX XX`.
  ///
  /// Cette méthode le **supprimait** (`242 61234567`), ce qui divergeait du
  /// backend (`formatMtnPhoneNumber` préfixe `242` sans rien retirer). Tant que
  /// l'encaissement était manuel, la divergence était sans effet : un humain
  /// lisait le numéro. Avec un prestataire qui envoie réellement l'argent, elle
  /// ferait partir la demande vers un numéro qui n'existe pas.
  String formatPhoneNumber(String phoneNumber, {String countryCode = '242'}) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Préfixe international composé (00…)
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }
    if (!cleaned.startsWith(countryCode)) {
      cleaned = countryCode + cleaned;
    }
    return cleaned;
  }

  /// Valide un mobile Congo-Brazzaville : `242` + `0` + `[456]` + 7 chiffres.
  /// Miroir du contrôle serveur (`^(\+?242)?0?[456]\d{7}$`).
  bool validatePhoneNumber(String phoneNumber, {String countryCode = '242'}) {
    final formatted = formatPhoneNumber(phoneNumber, countryCode: countryCode);
    return RegExp(r'^2420[456]\d{7}$').hasMatch(formatted);
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(api: ref.watch(apiClientProvider));
});
