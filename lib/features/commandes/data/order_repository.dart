import 'dart:async';
import 'dart:convert';

import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/models/checkout.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../models/order.dart';

part 'order_repository.g.dart';

/// Extraire le message d'erreur lisible depuis une réponse HTTP du backend
String _extractErrorMessage(http.Response response, String fallback) {
  try {
    final body = json.decode(utf8.decode(response.bodyBytes));
    if (body is Map<String, dynamic> && body['message'] != null) {
      final message = body['message'];
      // NestJS peut retourner un String ou une List de messages
      if (message is List) {
        return message.join('. ');
      }
      return message.toString();
    }
  } catch (_) {
    // Si le body n'est pas du JSON valide, on continue avec le fallback
  }
  return fallback;
}

@Riverpod(keepAlive: true)
class OrderRepository extends _$OrderRepository {
  @override
  Future<void> build() async {
    return;
  }

  Future<List<Order>> getMyOrders() async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/orders/users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> ordersJson = json.decode(utf8.decode(response.bodyBytes))["data"];
      return ordersJson.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception(_extractErrorMessage(
        response,
        'Impossible de charger vos commandes. Veuillez réessayer.',
      ));
    }
  }

  Future<Checkout> createOrders({
    String? adresseId,
    required String paymentMethod,
    required bool isDelivery,
    String? note
  }) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Construire le body selon le mode de livraison
    final Map<String, dynamic> bodyMap = {
      'paymentMethod': paymentMethod,
      'isDelivery': isDelivery,
    };

    // Ajouter l'adresse seulement si c'est une livraison
    if (isDelivery && adresseId != null) {
      bodyMap['adresseId'] = adresseId;
    }

    // Ajouter les notes si présentes
    if (note != null && note.isNotEmpty) {
      bodyMap['notes'] = note;
    }

    final body = json.encode(bodyMap);
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/orders/checkout'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 201) {
      return checkoutFromMap(response.body);
    } else {
      throw Exception(_extractErrorMessage(
        response,
        'Impossible de passer la commande. Veuillez réessayer.',
      ));
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/orders/$orderId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        response,
        'Impossible de supprimer la commande.',
      ));
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('Veuillez vous reconnecter.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/orders/$orderId/cancel'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(
        response,
        'Impossible d\'annuler la commande.',
      ));
    }
  }
}
