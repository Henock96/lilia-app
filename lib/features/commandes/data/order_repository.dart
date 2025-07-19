import 'dart:convert';

import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/models/checkout.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../models/order.dart';

part 'order_repository.g.dart';

@Riverpod(keepAlive: true)
class OrderRepository extends _$OrderRepository {
  @override
  Future<void> build() async {
    return;
  }

  final String _baseUrl = 'https://lilia-app.fly.dev';

  Future<List<Order>> getMyOrders() async {
    // Récupérer le jeton ID Firebase
    final token = await ref.read(firebaseIdTokenProvider.future); // Utilisez .future pour obtenir la valeur Future

    if (token == null) {
      // Gérer le cas où l'utilisateur n'est pas connecté ou le jeton n'est pas disponible
      throw Exception('User not authenticated. No Firebase ID token available.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Ajoutez le jeton
    };

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> ordersJson = json.decode(response.body);
        return ordersJson.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load orders: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server or fetch orders: $e');
    }
  }

  Future<Checkout> createOrders({
    required String adresseId,
    required String paymentMethod,
    String? newAddressRue,
    String? newAddressVille,
    String? newAddressCountry,
    String? newAddressComplement,
    String? newPhoneNumber,
  }) async {
    // Récupérer le jeton ID Firebase
    final token = await ref.read(firebaseIdTokenProvider.future); // Utilisez .future pour obtenir la valeur Future

    if (token == null) {
      // Gérer le cas où l'utilisateur n'est pas connecté ou le jeton n'est pas disponible
      throw Exception('User not authenticated. No Firebase ID token available.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Ajoutez le jeton
    };
    // Le backend attend CreateOrderDto: { adresseId, paymentMethod }
    // Si une nouvelle adresse est fournie, le backend devrait la gérer (ce n'est pas dans votre fonction createOrderFromCart)
    // Pour l'instant, je vais envoyer seulement adresseId et paymentMethod.
    // Si vous voulez créer l'adresse via l'app, il faudrait un autre endpoint pour ça.
    final body = json.encode({
      'adresseId': adresseId,
      'paymentMethod': paymentMethod,
      // Si votre backend peut créer une adresse à la volée via cet endpoint,
      // vous ajouteriez ces champs ici. Sinon, l'adresse doit exister.
      // 'newAddress': { 'rue': newAddressRue, ... }
      // 'newPhoneNumber': newPhoneNumber
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/orders/checkout'),
        headers: headers,
        body: body
      );

      if (response.statusCode == 201) {
        return checkoutFromMap(response.body);
      } else {
        throw Exception('Failed to load orders: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server or fetch orders: $e');
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('User not authenticated.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/orders/$orderId/cancel'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        // Essayez de décoder le message d'erreur du backend
        String errorMessage = 'Failed to cancel order';
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {
          // Le corps n'est pas du JSON ou n'a pas de message, utilisez le corps brut
          errorMessage = response.body;
        }
        throw Exception('$errorMessage (Code: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server or cancel order: $e');
    }
  }
}