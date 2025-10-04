import 'dart:async';
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

  final String _baseUrl = 'https://lilia-backend.onrender.com';

  Future<List<Order>> getMyOrders() async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('User not authenticated.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    final response = await http.get(
      Uri.parse('$_baseUrl/orders/me'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> ordersJson = json.decode(utf8.decode(response.bodyBytes));
      return ordersJson.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orders: ${response.body}');
    }
  }

  Future<Checkout> createOrders({
    required String adresseId,
    required String paymentMethod,
  }) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('User not authenticated.');
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = json.encode({
      'adresseId': adresseId,
      'paymentMethod': paymentMethod,
    });
    final response = await http.post(
      Uri.parse('$_baseUrl/orders/checkout'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 201) {
      return checkoutFromMap(response.body);
    } else {
      throw Exception('Failed to create order: ${response.body}');
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final token = await ref.read(firebaseIdTokenProvider.future);
    if (token == null) {
      throw Exception('User not authenticated.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    final response = await http.patch(
      Uri.parse('$_baseUrl/orders/$orderId/cancel'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel order: ${response.body}');
    }
  }
}
