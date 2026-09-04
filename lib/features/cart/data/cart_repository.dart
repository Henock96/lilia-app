import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
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
  final ApiClient _api;
  final _cartStreamController = StreamController<Cart?>.broadcast();
  bool _isClosed = false; // Flag pour savoir si le controller est fermé

  CartRepository(this._api);

  Map<String, dynamic>? _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  Map<String, dynamic>? _unwrapDataMap(dynamic value) {
    final map = _asMap(value);
    if (map == null) return null;
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    return map;
  }

  Cart? _cartFromData(dynamic data) {
    final map = _unwrapDataMap(data);
    return map == null ? null : Cart.fromJson(map);
  }

  /// Mappe une [ApiException] (parsing centralisé) vers une [CartException]
  /// en conservant les codes/messages attendus par l'UI panier.
  CartException _toCartException(
    ApiException e, {
    required String fallback,
    String fallbackCode = 'UNKNOWN_ERROR',
    String? notFound,
    bool useBackendMessageOn400 = false,
  }) {
    switch (e.kind) {
      case ApiErrorKind.network:
        return CartException(
          'Pas de connexion internet. Vérifiez votre connexion.',
          code: 'NO_INTERNET',
        );
      case ApiErrorKind.timeout:
        return CartException(
          'La requête a pris trop de temps. Vérifiez votre connexion.',
          code: 'TIMEOUT',
        );
      case ApiErrorKind.unauthorized:
        return CartException(
          'Utilisateur non authentifié.',
          code: 'UNAUTHENTICATED',
        );
      case ApiErrorKind.server:
        return CartException(
          'Erreur du serveur. Veuillez réessayer plus tard.',
          code: 'SERVER_ERROR',
        );
      case ApiErrorKind.client:
      case ApiErrorKind.unknown:
        final status = e.statusCode;
        if (status == 400 && useBackendMessageOn400) {
          return CartException(e.message, code: 'INVALID_DATA');
        }
        if (status == 403) {
          return CartException(
            'Cette commande ne vous appartient pas.',
            code: 'FORBIDDEN',
          );
        }
        if (status == 404 && notFound != null) {
          return CartException(notFound, code: 'NOT_FOUND');
        }
        return CartException(fallback, code: fallbackCode);
    }
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

    try {
      final res = await _api.getJson('/cart');
      _safeAdd(_cartFromData(res.data));
    } on ApiException catch (e, stackTrace) {
      // Invité ou session expirée → panier vide (pas d'erreur affichée).
      if (e.kind == ApiErrorKind.unauthorized) {
        _safeAdd(null);
      } else {
        debugPrint('Error in getCart: ${e.message}');
        _safeAddError(e, stackTrace);
      }
    }
  }

  Future<void> addToCart({
    required String variantId,
    required int quantity,
    int maxRetries = 2,
  }) async {
    try {
      await _api.postJson(
        '/cart/add',
        body: {'variantId': variantId, 'quantite': quantity},
      );
      debugPrint('✅ Item added to cart successfully');
      await getCart();
    } on ApiException catch (e) {
      debugPrint('❌ Error adding to cart: ${e.message}');
      throw _toCartException(
        e,
        fallback: 'Une erreur est survenue.',
        fallbackCode: 'UNKNOWN',
        notFound: 'Produit non trouvé.',
        useBackendMessageOn400: true,
      );
    }
  }

  Future<void> updateItemQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    if (quantity == 0) {
      await removeItem(cartItemId: cartItemId);
      return;
    }

    try {
      await _api.patchJson(
        '/cart/items/$cartItemId',
        body: {'quantite': quantity},
      );
      await getCart();
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de mettre à jour la quantité.',
        fallbackCode: 'UPDATE_FAILED',
      );
    }
  }

  Future<void> removeItem({required String cartItemId}) async {
    try {
      await _api.deleteJson('/cart/items/$cartItemId');
      await getCart();
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de supprimer l\'article.',
        fallbackCode: 'DELETE_FAILED',
      );
    }
  }

  /// Ajoute un menu complet au panier
  Future<void> addMenuToCart({
    required String menuId,
    required int quantity,
  }) async {
    try {
      final res = await _api.postJson(
        '/cart/add-menu',
        body: {'menuId': menuId, 'quantite': quantity},
      );
      _safeAdd(_cartFromData(res.data));
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Une erreur est survenue.',
        fallbackCode: 'UNKNOWN',
        notFound: 'Menu non trouvé.',
        useBackendMessageOn400: true,
      );
    }
  }

  /// Met à jour la quantité d'un menu dans le panier
  Future<void> updateMenuQuantity({
    required String menuId,
    required int quantity,
  }) async {
    if (quantity == 0) {
      await removeMenu(menuId: menuId);
      return;
    }

    try {
      final res = await _api.patchJson(
        '/cart/menus/$menuId',
        body: {'quantite': quantity},
      );
      _safeAdd(_cartFromData(res.data));
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de mettre à jour la quantité du menu.',
        fallbackCode: 'UPDATE_FAILED',
      );
    }
  }

  /// Supprime un menu complet du panier
  Future<void> removeMenu({required String menuId}) async {
    try {
      final res = await _api.deleteJson('/cart/menus/$menuId');
      _safeAdd(_cartFromData(res.data));
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de supprimer le menu.',
        fallbackCode: 'DELETE_FAILED',
      );
    }
  }

  /// Vide tout le panier via l'API backend
  Future<void> clearAllItems() async {
    try {
      await _api.deleteJson('/cart/clear');
      _safeAdd(null);
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de vider le panier.',
        fallbackCode: 'CLEAR_FAILED',
      );
    }
  }

  /// Recommande une commande précédente
  /// Ajoute tous les produits de la commande au panier
  Future<Map<String, dynamic>> reorderFromOrder({
    required String orderId,
  }) async {
    try {
      final res = await _api.postJson('/orders/$orderId/reorder');
      final data = _asMap(res.data) ?? <String, dynamic>{};
      final result = _asMap(data['data']) ?? data;
      debugPrint('Order reordered successfully');

      // Rafraîchir le panier
      await getCart();

      return result;
    } on ApiException catch (e) {
      debugPrint('❌ Error reordering: ${e.message}');
      throw _toCartException(
        e,
        fallback: 'Une erreur est survenue.',
        fallbackCode: 'UNKNOWN',
        notFound: 'Commande non trouvée.',
        useBackendMessageOn400: true,
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
