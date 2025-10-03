import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

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
    return PaymentResponse(
      paymentId: json['paymentId'] as String,
      referenceId: json['referenceId'] as String,
      message: json['message'] as String? ?? 'Payment initiated',
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
  final http.Client _httpClient;
  final FirebaseAuthenticationRepository _authRepository;
  final String baseUrl;

  PaymentService({
    required http.Client httpClient,
    required FirebaseAuthenticationRepository authRepository,
    String? baseUrl,
  }) : _httpClient = httpClient,
       _authRepository = authRepository,
       baseUrl = baseUrl ?? 'https://lilia-backend.onrender.com';

  // Créer un paiement
  Future<PaymentResponse> createPayment({
    required String orderId,
    required double amount,
    required String phoneNumber,
    String currency = 'FCFA',
    String? payerMessage,
  }) async {
    try {
      debugPrint('💳 Creating payment for order: $orderId');
      debugPrint('💳 Amount: $amount $currency');
      debugPrint('💳 Phone: $phoneNumber');

      final idToken = await _authRepository.getIdToken();
      if (idToken == null) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$baseUrl/payments/create');

      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'orderId': orderId,
              'amount': amount,
              'currency': currency,
              'phoneNumber': phoneNumber,
              'payerMessage': payerMessage ?? 'Paiement commande $orderId',
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('💳 Payment response status: ${response.statusCode}');
      debugPrint('💳 Payment response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return PaymentResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create payment');
      }
    } catch (e) {
      debugPrint('❌ Error creating payment: $e');
      rethrow;
    }
  }

  // Vérifier le statut du paiement
  Future<PaymentStatusResponse> checkPaymentStatus(String paymentId) async {
    try {
      debugPrint('🔍 Checking payment status: $paymentId');

      final idToken = await _authRepository.getIdToken();
      if (idToken == null) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$baseUrl/payments/$paymentId/status');

      final response = await _httpClient
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('🔍 Status check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PaymentStatusResponse.fromJson(data);
      } else {
        throw Exception('Failed to check payment status');
      }
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

  // Formater le numéro de téléphone
  String formatPhoneNumber(String phoneNumber, {String countryCode = '242'}) {
    // Nettoyer le numéro
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Retirer le + si présent
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    // Ajouter le code pays si absent
    if (!cleaned.startsWith(countryCode)) {
      // Si le numéro commence par 6 ou 7 (typique Cameroun)
      if (cleaned.startsWith('6') || cleaned.startsWith('7')) {
        cleaned = countryCode + cleaned;
      }
    }

    return cleaned;
  }

  // Valider le numéro de téléphone
  bool validatePhoneNumber(String phoneNumber, {String countryCode = '242'}) {
    final formatted = formatPhoneNumber(phoneNumber, countryCode: countryCode);

    // Patterns pour différents pays
    final patterns = {
      '237': RegExp(r'^237[67]\d{8}$'), // Cameroun
      '225': RegExp(r'^225\d{10}$'), // Côte d'Ivoire
      '243': RegExp(r'^243[89]\d{8}$'), // RDC
      '242': RegExp(r'^242\d{9}$'), // Congo-Brazzaville
    };

    final pattern = patterns[countryCode] ?? RegExp(r'^\d{9,15}$');
    return pattern.hasMatch(formatted);
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final httpClient = ref.watch(httpClientProvider);
  return PaymentService(httpClient: httpClient, authRepository: authRepository);
});
