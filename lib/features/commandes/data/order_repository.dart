import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/models/checkout.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:lilia_app/utils/json_isolate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../models/order.dart';

part 'order_repository.g.dart';

/// Une page de commandes : les lignes, et de quoi savoir s'il en reste.
class OrdersPage {
  const OrdersPage({
    required this.orders,
    required this.page,
    required this.totalPages,
  });

  final List<Order> orders;
  final int page;
  final int totalPages;

  /// `GET /orders/my` rend `meta.totalPages` (minimum 1). Comparer les pages
  /// plutôt que compter les lignes reçues : une page pleine n'implique pas
  /// qu'il en existe une suivante.
  bool get hasMore => page < totalPages;

  static const vide = OrdersPage(orders: [], page: 1, totalPages: 1);
}

/// Décodage + mapping d'une page de commandes `{ data: [...], meta: {...} }`.
/// Top-level → exécutable sur isolate (cf. [parseJson]). Les commandes
/// portent des items + produits imbriqués : parsing potentiellement lourd.
OrdersPage _parseOrdersPage(String body) {
  final decoded = json.decode(body);
  final enveloppe = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
  final data = enveloppe['data'];
  final list = data is List ? data : const <dynamic>[];
  final meta = enveloppe['meta'];
  final metaMap = meta is Map<String, dynamic> ? meta : const <String, dynamic>{};

  return OrdersPage(
    orders: list.whereType<Map<String, dynamic>>().map(Order.fromJson).toList(),
    page: (metaMap['page'] as num?)?.toInt() ?? 1,
    // Absent d'une vieille réponse : on suppose une page unique plutôt que de
    // laisser un défilement réclamer indéfiniment la suivante.
    totalPages: (metaMap['totalPages'] as num?)?.toInt() ?? 1,
  );
}

@Riverpod(keepAlive: true)
class OrderRepository extends _$OrderRepository {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<void> build() async {}

  /// Taille de page. Bornée à 100 côté serveur (`PaginationQueryDto`).
  static const pageSize = 20;

  /// Une page de l'historique.
  ///
  /// ⚠️ L'appel ne passait **aucun** paramètre, et le serveur applique alors
  /// son défaut : `limit = 20`. Le client recevait donc au plus vingt
  /// commandes, sans jamais demander la suite — et comme
  /// `OrderDetailPage` cherchait sa commande **dans cette liste**, tout
  /// au-delà de la vingtième affichait « Commande introuvable ». Un client
  /// fidèle perdait son historique, ses reçus et son bouton « Commander à
  /// nouveau ».
  Future<OrdersPage> getMyOrders({int page = 1}) async {
    // Corps brut → parsing déporté sur isolate au-delà du seuil (perf).
    final body = await _api.getText(
      '/orders/my',
      query: {'page': '$page', 'limit': '$pageSize'},
    );
    return parseJson(body, _parseOrdersPage);
  }

  /// **Une** commande, par sa route dédiée.
  ///
  /// `GET /orders/:id` existait côté serveur depuis toujours et n'avait aucun
  /// appelant : le détail se contentait de filtrer la première page de la
  /// liste. « Absente de la page 1 » n'est pas « inexistante », et c'est
  /// pourtant ce que l'écran annonçait.
  Future<Order> getOrder(String orderId) async {
    final res = await _api.getJson('/orders/$orderId');
    return Order.fromJson(ApiResponse.mapOf(res.data));
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

  // `reorder(String)` a été SUPPRIMÉ : aucun appelant. La recommande passe
  // par `CartController.reorder({orderId})`, qui consomme le rapport renvoyé
  // par la route et relit le panier — ce que cette méthode ne faisait pas.

  Future<void> deleteOrder(String orderId) =>
      _api.deleteJson('/orders/$orderId');

  Future<void> cancelOrder(String orderId) =>
      _api.patchJson('/orders/$orderId/cancel');

  /// Signale un problème sur la commande (Master Audit v1, F-06) — ouvre un
  /// incident côté Lilia Food. `kind` : NOT_RECEIVED, WRONG_ORDER, LATE, OTHER.
  Future<void> reportIssue(String orderId, String kind, {String? message}) =>
      _api.postJson(
        '/incidents/orders/$orderId/report',
        body: {'kind': kind, 'message': ?message},
      );
}
