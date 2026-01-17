import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/models/cart.dart';

/// Exception personnalisée pour les erreurs de panier
class CartException implements Exception {
  final String message;
  final String? code;

  CartException(this.message, {this.code});

  @override
  String toString() => message;
}

class CartRepository {
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
            Uri.parse('${AppConstants.baseUrl}/cart'),
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
    int maxRetries = 2,
  }) async {
    final token = await _getIdToken();
    if (token == null) {
      throw CartException(
        'Utilisateur non authentifié.',
        code: 'UNAUTHENTICATED',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/cart/add'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'variantId': variantId, 'quantite': quantity}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'La requête a pris trop de temps. Vérifiez votre connexion.',
              );
            },
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Item added to cart successfully');
        await getCart();
      } else if (response.statusCode == 400) {
        throw CartException(
          'Données invalides. Veuillez réessayer.',
          code: 'INVALID_DATA',
        );
      } else if (response.statusCode == 404) {
        throw CartException(
          'Produit non trouvé.',
          code: 'NOT_FOUND',
        );
      } else if (response.statusCode >= 500) {
        throw CartException(
          'Erreur du serveur. Veuillez réessayer plus tard.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw CartException(
          'Erreur: ${response.statusCode}',
          code: 'UNKNOWN_ERROR',
        );
      }
    } on SocketException {
      debugPrint('📡 No internet connection');
      throw CartException(
        'Pas de connexion internet. Vérifiez votre connexion.',
        code: 'NO_INTERNET',
      );
    } on TimeoutException {
      debugPrint('⏱️ Request timeout');
      throw CartException(
        'La requête a pris trop de temps. Vérifiez votre connexion.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ Error adding to cart: $e');
      if (e is CartException) {
        rethrow;
      }
      throw CartException(
        'Une erreur est survenue: ${e.toString()}',
        code: 'UNKNOWN',
      );
    }
  }

  Future<void> updateItemQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    final token = await _getIdToken();
    if (token == null) {
      throw CartException(
        'Utilisateur non authentifié.',
        code: 'UNAUTHENTICATED',
      );
    }

    if (quantity == 0) {
      await removeItem(cartItemId: cartItemId);
      return;
    }

    try {
      final response = await http
          .patch(
            Uri.parse('${AppConstants.baseUrl}/cart/items/$cartItemId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'quantite': quantity}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await getCart();
      } else {
        throw CartException(
          'Impossible de mettre à jour la quantité.',
          code: 'UPDATE_FAILED',
        );
      }
    } on SocketException {
      throw CartException(
        'Pas de connexion internet.',
        code: 'NO_INTERNET',
      );
    } on TimeoutException {
      throw CartException(
        'La requête a pris trop de temps.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      if (e is CartException) rethrow;
      throw CartException(
        'Erreur lors de la mise à jour: ${e.toString()}',
        code: 'UNKNOWN',
      );
    }
  }

  Future<void> removeItem({required String cartItemId}) async {
    final token = await _getIdToken();
    if (token == null) {
      throw CartException(
        'Utilisateur non authentifié.',
        code: 'UNAUTHENTICATED',
      );
    }

    try {
      final response = await http
          .delete(
            Uri.parse('${AppConstants.baseUrl}/cart/items/$cartItemId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await getCart();
      } else {
        throw CartException(
          'Impossible de supprimer l\'article.',
          code: 'DELETE_FAILED',
        );
      }
    } on SocketException {
      throw CartException(
        'Pas de connexion internet.',
        code: 'NO_INTERNET',
      );
    } on TimeoutException {
      throw CartException(
        'La requête a pris trop de temps.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      if (e is CartException) rethrow;
      throw CartException(
        'Erreur lors de la suppression: ${e.toString()}',
        code: 'UNKNOWN',
      );
    }
  }

  /// Recommande une commande précédente
  /// Ajoute tous les produits de la commande au panier
  Future<Map<String, dynamic>> reorderFromOrder({
    required String orderId,
  }) async {
    final token = await _getIdToken();
    if (token == null) {
      throw CartException(
        'Utilisateur non authentifié.',
        code: 'UNAUTHENTICATED',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/orders/$orderId/reorder'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'La requête a pris trop de temps. Vérifiez votre connexion.',
              );
            },
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Order reordered successfully');
        final data = jsonDecode(response.body);

        // Rafraîchir le panier
        await getCart();

        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw CartException(
          errorData['message'] ?? 'Erreur lors de la recommande.',
          code: 'INVALID_DATA',
        );
      } else if (response.statusCode == 403) {
        throw CartException(
          'Cette commande ne vous appartient pas.',
          code: 'FORBIDDEN',
        );
      } else if (response.statusCode == 404) {
        throw CartException(
          'Commande non trouvée.',
          code: 'NOT_FOUND',
        );
      } else if (response.statusCode >= 500) {
        throw CartException(
          'Erreur du serveur. Veuillez réessayer plus tard.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw CartException(
          'Erreur: ${response.statusCode}',
          code: 'UNKNOWN_ERROR',
        );
      }
    } on SocketException {
      debugPrint('📡 No internet connection');
      throw CartException(
        'Pas de connexion internet. Vérifiez votre connexion.',
        code: 'NO_INTERNET',
      );
    } on TimeoutException {
      debugPrint('⏱️ Request timeout');
      throw CartException(
        'La requête a pris trop de temps. Vérifiez votre connexion.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ Error reordering: $e');
      if (e is CartException) {
        rethrow;
      }
      throw CartException(
        'Une erreur est survenue: ${e.toString()}',
        code: 'UNKNOWN',
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
