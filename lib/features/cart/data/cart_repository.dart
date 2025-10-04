import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/models/cart.dart';

class CartRepository {
  final String _baseUrl = 'https://lilia-backend.onrender.com';
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final _cartStreamController = StreamController<Cart?>.broadcast();
  bool _isClosed = false; // Flag pour savoir si le controller est fermé

  CartRepository();

  Future<String?> _getIdToken() async {
    final user = _firebaseAuth.currentUser;
    return await user?.getIdToken();
  }

  Stream<Cart?> watchCart() => _cartStreamController.stream;

  // Vérifier si le controller est fermé avant d'ajouter
  void _safeAdd(Cart? cart) {
    if (!_isClosed && !_cartStreamController.isClosed) {
      _cartStreamController.add(cart);
    }
  }

  void _safeAddError(Object error, [StackTrace? stackTrace]) {
    if (!_isClosed && !_cartStreamController.isClosed) {
      _cartStreamController.addError(error, stackTrace);
    }
  }

  void clearCart() {
    _safeAdd(null);
  }

  Future<void> getCart() async {
    if (_isClosed) {
      debugPrint('CartRepository is closed, skipping getCart');
      return;
    }

    final token = await _getIdToken();
    if (token == null) {
      _safeAdd(null);
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/cart'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cart = data != null ? Cart.fromJson(data) : null;
        _safeAdd(cart);
      } else {
        _safeAdd(null);
      }
    } catch (e, stackTrace) {
      debugPrint('Error in getCart: $e');
      _safeAddError(e, stackTrace);
    }
  }

  Future<void> addToCart({
    required String variantId,
    required int quantity,
  }) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifié.');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/cart/add'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'variantId': variantId, 'quantite': quantity}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      await getCart();
    } else {
      throw Exception('Erreur lors de l\'ajout au panier: ${response.body}');
    }
  }

  Future<void> updateItemQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifié.');

    if (quantity == 0) {
      await removeItem(cartItemId: cartItemId);
      return;
    }

    final response = await http
        .patch(
          Uri.parse('$_baseUrl/cart/items/$cartItemId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'quantite': quantity}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      await getCart();
    } else {
      throw Exception(
        'Erreur lors de la mise à jour de la quantité: ${response.body}',
      );
    }
  }

  Future<void> removeItem({required String cartItemId}) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifié.');

    final response = await http
        .delete(
          Uri.parse('$_baseUrl/cart/items/$cartItemId'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      await getCart();
    } else {
      throw Exception(
        'Erreur lors de la suppression de l\'article: ${response.body}',
      );
    }
  }

  void dispose() {
    _isClosed = true;
    if (!_cartStreamController.isClosed) {
      _cartStreamController.close();
    }
  }
}
