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

/// Transport HTTP du panier — **et rien d'autre**.
///
/// Il ne détient aucun état et ne diffuse rien : chaque méthode rend ce que le
/// serveur a répondu. L'état du panier, la mise à jour optimiste et le
/// rollback vivent dans `CartController`.
///
/// Le `StreamController.broadcast` qui vivait ici a disparu : il obligeait le
/// contrôleur à observer sa propre source de vérité de l'extérieur, sans
/// aucun endroit où poser un instantané avant mutation.
class CartRepository {
  final ApiClient _api;

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

  /// Le panier porté par une réponse, ou `null` si la réponse n'en contient
  /// pas.
  ///
  /// ⚠️ La vérification des deux champs n'est pas défensive par principe.
  /// `_unwrapDataMap` retombe sur l'enveloppe complète quand `data` n'est pas
  /// une carte, et `Cart.fromJson` est tolérant : une réponse quelconque —
  /// page d'erreur d'un proxy, enveloppe réécrite — se lisait donc comme un
  /// **panier vide**, indiscernable d'un panier réellement vidé. Le contrôleur
  /// l'aurait adopté et l'écran se serait vidé sans que rien n'ait été
  /// supprimé.
  ///
  /// Un panier porte toujours un identifiant et une liste d'articles. Sans ces
  /// deux-là, on préfère ne rien savoir plutôt que de croire à tort.
  Cart? _cartFromData(dynamic data) {
    final map = _unwrapDataMap(data);
    if (map == null) return null;
    if (map['id'] is! String || map['items'] is! List) return null;
    return Cart.fromJson(map);
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

  /// Lit le panier serveur.
  ///
  /// Invité ou session expirée → `null` (panier vide), pas une erreur : c'est
  /// un état normal de l'application, pas une panne à signaler au client.
  Future<Cart?> getCart() async {
    try {
      final res = await _api.getJson('/cart');
      return _cartFromData(res.data);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) return null;
      debugPrint('Error in getCart: ${e.message}');
      rethrow;
    }
  }

  /// ⚠️ **Ne jamais faire suivre une mutation d'un `getCart()`.**
  ///
  /// Les six routes de mutation du panier se terminent, côté backend, par
  /// `return this.common.getCart(firebaseUid)` — la réponse *est* le panier
  /// complet. Le `await getCart()` qui suivait ici doublait le délai de chaque
  /// ajout (mesuré : 1957 ms au lieu de ~980 ms) pour redemander une donnée
  /// déjà reçue. Les trois méthodes menus de ce fichier consommaient déjà
  /// correctement la réponse ; celles sur les articles avaient divergé.
  ///
  /// Seules exceptions, vérifiées : `DELETE /cart/clear` (renvoie
  /// `{ count: N }`) et `POST /orders/:id/reorder` (renvoie un rapport de
  /// recommande). Ces deux-là doivent relire le panier.
  Future<Cart?> addToCart({
    required String variantId,
    required int quantity,
  }) async {
    try {
      final res = await _api.postJson(
        '/cart/add',
        body: {'variantId': variantId, 'quantite': quantity},
      );
      return _cartFromData(res.data);
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

  Future<Cart?> updateItemQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    if (quantity == 0) {
      return removeItem(cartItemId: cartItemId);
    }

    try {
      final res = await _api.patchJson(
        '/cart/items/$cartItemId',
        body: {'quantite': quantity},
      );
      return _cartFromData(res.data);
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de mettre à jour la quantité.',
        fallbackCode: 'UPDATE_FAILED',
      );
    }
  }

  Future<Cart?> removeItem({required String cartItemId}) async {
    try {
      final res = await _api.deleteJson('/cart/items/$cartItemId');
      return _cartFromData(res.data);
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de supprimer l\'article.',
        fallbackCode: 'DELETE_FAILED',
      );
    }
  }

  /// Ajoute un menu complet au panier
  Future<Cart?> addMenuToCart({
    required String menuId,
    required int quantity,
  }) async {
    try {
      final res = await _api.postJson(
        '/cart/add-menu',
        body: {'menuId': menuId, 'quantite': quantity},
      );
      return _cartFromData(res.data);
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
  Future<Cart?> updateMenuQuantity({
    required String menuId,
    required int quantity,
  }) async {
    if (quantity == 0) {
      return removeMenu(menuId: menuId);
    }

    try {
      final res = await _api.patchJson(
        '/cart/menus/$menuId',
        body: {'quantite': quantity},
      );
      return _cartFromData(res.data);
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de mettre à jour la quantité du menu.',
        fallbackCode: 'UPDATE_FAILED',
      );
    }
  }

  /// Supprime un menu complet du panier
  Future<Cart?> removeMenu({required String menuId}) async {
    try {
      final res = await _api.deleteJson('/cart/menus/$menuId');
      return _cartFromData(res.data);
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de supprimer le menu.',
        fallbackCode: 'DELETE_FAILED',
      );
    }
  }

  /// Vide tout le panier via l'API backend.
  ///
  /// ⚠️ Contrat différent des six autres mutations : `CartService.clearCart`
  /// renvoie le `{ count }` d'un `deleteMany`, ou rien si aucun panier
  /// n'existe. Il n'y a donc pas de panier à adopter — l'état résultant est
  /// simplement « vide », que l'appelant connaît sans relire quoi que ce soit.
  Future<void> clearAllItems() async {
    try {
      await _api.deleteJson('/cart/clear');
    } on ApiException catch (e) {
      throw _toCartException(
        e,
        fallback: 'Impossible de vider le panier.',
        fallbackCode: 'CLEAR_FAILED',
      );
    }
  }

  /// Recommande une commande précédente : recopie ses articles dans le panier.
  ///
  /// ⚠️ Second contrat différent : `POST /orders/:id/reorder` renvoie un
  /// **rapport de recommande** (articles ajoutés, indisponibles…), pas le
  /// panier. La relecture qui suit est donc nécessaire ici — c'est la seule
  /// mutation du panier pour laquelle elle le reste.
  Future<({Map<String, dynamic> report, Cart? cart})> reorderFromOrder({
    required String orderId,
  }) async {
    try {
      final res = await _api.postJson('/orders/$orderId/reorder');
      final data = _asMap(res.data) ?? <String, dynamic>{};
      final report = _asMap(data['data']) ?? data;
      return (report: report, cart: await getCart());
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

}
