import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:lilia_app/core/network/api_client.dart';
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

@Riverpod(keepAlive: true)
class OrderRepository extends _$OrderRepository {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<void> build() async {}

  Future<List<Order>> getMyOrders() async {
    // Corps brut → parsing déporté sur isolate au-delà du seuil (perf).
    final body = await _api.getText('/orders/my');
    return parseJson(body, _parseOrders);
  }

  /// Télécharge le reçu PDF d'une commande payée.
  Future<Uint8List> downloadReceipt(String orderId) =>
      _api.downloadBytes('/orders/$orderId/receipt');

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
    final bodyMap = <String, dynamic>{
      'paymentMethod': paymentMethod,
      'isDelivery': isDelivery,
      if (isDelivery && adresseId != null) 'adresseId': adresseId,
      if (note != null && note.isNotEmpty) 'notes': note,
      if (contactPhone != null && contactPhone.isNotEmpty)
        'contactPhone': contactPhone,
      if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
      if (useLoyaltyPoints) 'useLoyaltyPoints': true,
      'deliveryLatitude': ?deliveryLatitude,
      'deliveryLongitude': ?deliveryLongitude,
      if (scheduledFor != null) ...{
        'isPreorder': true,
        'scheduledFor': scheduledFor.toUtc().toIso8601String(),
      },
    };

    final res = await _api.postJson(
      '/orders/checkout',
      body: bodyMap,
      headers: idempotencyKey != null
          ? {'Idempotency-Key': idempotencyKey}
          : null,
    );
    // checkoutFromMap attend l'enveloppe JSON brute { message, data: {...} }.
    return checkoutFromMap(json.encode(res.data));
  }

  Future<void> reorder(String orderId) =>
      _api.postJson('/orders/$orderId/reorder');

  Future<void> deleteOrder(String orderId) =>
      _api.deleteJson('/orders/$orderId');

  Future<void> cancelOrder(String orderId) =>
      _api.patchJson('/orders/$orderId/cancel');
}
