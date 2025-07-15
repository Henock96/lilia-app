import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/models/cart.dart';

class CartRepository {
  final String _baseUrl = 'http://10.0.2.2:3000';
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final _cartStreamController = StreamController<Cart?>.broadcast();

  // Le constructeur est maintenant vide et ne fait plus rien de lui-même.
  CartRepository();

  Future<String?> _getIdToken() async {
    final user = _firebaseAuth.currentUser;
    return await user?.getIdToken();
  }

  Stream<Cart?> watchCart() => _cartStreamController.stream;

  void clearCart() {
    _cartStreamController.add(null);
  }

  Future<void> getCart() async {
    final token = await _getIdToken();
    if (token == null) {
      _cartStreamController.add(null);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cart'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final cart = Cart.fromJson(jsonDecode(response.body));
        _cartStreamController.add(cart);
      } else {
        _cartStreamController.add(null);
      }
    } catch (e) {
      _cartStreamController.addError(e);
    }
  }

  Future<void> addToCart({required String variantId, required int quantity}) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifié.');

    final response = await http.post(
      Uri.parse('$_baseUrl/cart/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'variantId': variantId, 'quantite': quantity}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      await getCart();
    } else {
      throw Exception('Erreur lors de l\'ajout au panier: ${response.body}');
    }
  }

  Future<void> updateItemQuantity({required String cartItemId, required int quantity}) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifié.');

    // Si la quantité est nulle, on supprime l'article
    if (quantity == 0) {
      await removeItem(cartItemId: cartItemId);
      return;
    }

    final response = await http.patch(
      Uri.parse('$_baseUrl/cart/items/$cartItemId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'quantite': quantity}),
    );

    if (response.statusCode == 200) {
      await getCart();
    } else {
      throw Exception('Erreur lors de la mise à jour de la quantité: ${response.body}');
    }
  }

  Future<void> removeItem({required String cartItemId}) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Utilisateur non authentifié.');

    final response = await http.delete(
      Uri.parse('$_baseUrl/cart/items/$cartItemId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      await getCart();
    } else {
      throw Exception('Erreur lors de la suppression de l\'article: ${response.body}');
    }
  }

  void dispose() {
    _cartStreamController.close();
  }
}