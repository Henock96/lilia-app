import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';

enum PaymentStatus { pending, success, failed, cancelled }

class PaymentResponse {
  final String paymentId;
  final String referenceId;
  final String message;

  PaymentResponse({
    required this.paymentId,
    required this.referenceId,
    required this.message,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    // Deux formats backend selon PAYMENT_MODE :
    //  • MTN     → { paymentId, referenceId, message? }
    //  • MANUAL  → { paymentId, mode, instructions: { reference, message, ... } }
    final instructions = json['instructions'] as Map<String, dynamic>?;
    return PaymentResponse(
      paymentId: json['paymentId'] as String,
      referenceId:
          (json['referenceId'] ?? instructions?['reference']) as String? ?? '',
      message:
          (json['message'] ?? instructions?['message']) as String? ??
          'Paiement initié',
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

  PaymentStatusResponse({
    required this.paymentId,
    required this.status,
    this.financialTransactionId,
    this.amount,
    this.currency,
    this.reason,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      paymentId: json['paymentId'] as String,
      status: _parseStatus(json['status'] as String),
      financialTransactionId: json['financialTransactionId'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      reason: json['reason'] as String?,
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
  Future<PaymentResponse> createPayment({
    required String orderId,
    required double amount,
    required String phoneNumber,
    String currency = 'XAF', // code ISO — cohérent avec le reste de l'app (C16)
    String? payerMessage,
  }) async {
    try {
      debugPrint('💳 Creating payment for order: $orderId');
      debugPrint('💳 Amount: $amount $currency');
      debugPrint('💳 Payment phone provided.');

      final res = await _api.postJson('/payments', body: {
        'orderId': orderId,
        'amount': amount,
        'currency': currency,
        'phoneNumber': phoneNumber,
        'payerMessage': payerMessage ?? 'Paiement commande $orderId',
      });

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
        await Future.delayed(pollInterval);
      } catch (e) {
        debugPrint('⚠️ Error during polling: $e');
        await Future.delayed(pollInterval);
      }
    }

    throw Exception('Payment verification timeout');
  }

  // Formater le numéro vers le format E.164 Congo-Brazzaville (242XXXXXXXX).
  // App Congo-only : on ne garde que l'indicatif 242 (C17).
  String formatPhoneNumber(String phoneNumber, {String countryCode = '242'}) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Retirer le préfixe international 00 si présent
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }
    // Numéro local Congo : 0[456]XXXXXXX → retirer le 0 de trunk
    if (!cleaned.startsWith(countryCode) && cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    // Ajouter l'indicatif pays si absent
    if (!cleaned.startsWith(countryCode)) {
      cleaned = countryCode + cleaned;
    }

    return cleaned;
  }

  // Valider un mobile Congo-Brazzaville : 242 + [456] + 7 chiffres (MTN/Airtel).
  // Mirroir du backend B21 (`^(242)?0?[456][0-9]{7}$`).
  bool validatePhoneNumber(String phoneNumber, {String countryCode = '242'}) {
    final formatted = formatPhoneNumber(phoneNumber, countryCode: countryCode);
    return RegExp(r'^242[456]\d{7}$').hasMatch(formatted);
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(api: ref.watch(apiClientProvider));
});
