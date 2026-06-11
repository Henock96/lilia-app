import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/models/checkout.dart';
import 'package:lilia_app/utils/json_isolate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../models/order.dart';

part 'order_repository.g.dart';

/// Décodage + mapping de la liste des commandes `{ data: [...] }`.
/// Top-level → exécutable sur isolate (cf. [parseJson]). Les commandes
/// portent des items + produits imbriqués : parsing potentiellement lourd.
List<Order> _parseOrders(String body) {
  final decoded = json.decode(body);
  final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
  final list = data is List ? data : const <dynamic>[];
  return list.whereType<Map<String, dynamic>>().map(Order.fromJson).toList();
}

String _extractErrorMessage(http.Response response, String fallback) {
  try {
    final body = json.decode(utf8.decode(response.bodyBytes));
    if (body is Map<String, dynamic> && body['message'] != null) {
      final message = body['message'];
      if (message is List) return message.join('. ');
      return message.toString();
    }
  } catch (_) {}
  return fallback;
}

@Riverpod(keepAlive: true)
class OrderRepository extends _$OrderRepository {
  @override
  Future<void> build() async {}

  Future<List<Order>> getMyOrders() async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) throw Exception('Veuillez vous reconnecter.');
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/orders/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return parseJson(utf8.decode(response.bodyBytes), _parseOrders);
    } else {
      throw Exception(
        _extractErrorMessage(response, 'Impossible de charger vos commandes.'),
      );
    }
  }

  /// Télécharge le reçu PDF d'une commande payée.
  /// Renvoie les octets du PDF (à écrire dans un fichier puis partager).
  Future<Uint8List> downloadReceipt(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) throw Exception('Veuillez vous reconnecter.');
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/orders/$orderId/receipt'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception(
      _extractErrorMessage(response, 'Impossible de générer le reçu.'),
    );
  }

  Future<Checkout> createOrders({
    String? adresseId,
    required String paymentMethod,
    required bool isDelivery,
    String? note,
    String? contactPhone,
    String? promoCode,
    bool useLoyaltyPoints = false,
    String? idempotencyKey,
    double? deliveryLatitude,
    double? deliveryLongitude,
    // LIL-122 : commande programmée (panier 100% madeToOrder)
    DateTime? scheduledFor,
  }) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) throw Exception('Veuillez vous reconnecter.');

    final Map<String, dynamic> bodyMap = {
      'paymentMethod': paymentMethod,
      'isDelivery': isDelivery,
      if (isDelivery && adresseId != null) 'adresseId': adresseId,
      if (note != null && note.isNotEmpty) 'notes': note,
      if (contactPhone != null && contactPhone.isNotEmpty)
        'contactPhone': contactPhone,
      if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
      if (useLoyaltyPoints) 'useLoyaltyPoints': true,
      if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
      if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
      if (scheduledFor != null) ...{
        'isPreorder': true,
        'scheduledFor': scheduledFor.toUtc().toIso8601String(),
      },
    };

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/orders/checkout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      },
      body: json.encode(bodyMap),
    );
    if (response.statusCode == 201) {
      return checkoutFromMap(response.body);
    } else {
      throw Exception(
        _extractErrorMessage(response, 'Impossible de passer la commande.'),
      );
    }
  }

  Future<void> reorder(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) throw Exception('Veuillez vous reconnecter.');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/orders/$orderId/reorder'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        _extractErrorMessage(response, 'Impossible de recommander.'),
      );
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) throw Exception('Veuillez vous reconnecter.');
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/orders/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(response, 'Impossible de supprimer la commande.'),
      );
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) throw Exception('Veuillez vous reconnecter.');
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/orders/$orderId/cancel'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(response, 'Impossible d\'annuler la commande.'),
      );
    }
  }
}
