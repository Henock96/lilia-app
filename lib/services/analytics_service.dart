import 'package:firebase_analytics/firebase_analytics.dart';

/// Service centralisé pour le tracking Firebase Analytics.
/// Permet de suivre les événements clés de l'application.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalytics get instance => _analytics;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // === ÉVÉNEMENTS COMMANDE ===

  static Future<void> logOrderCreated({
    required String orderId,
    required double total,
    required String paymentMethod,
    required bool isDelivery,
    required String restaurantId,
    int? itemCount,
  }) async {
    await _analytics.logEvent(
      name: 'order_created',
      parameters: {
        'order_id': orderId,
        'total': total,
        'payment_method': paymentMethod,
        'is_delivery': isDelivery.toString(),
        'restaurant_id': restaurantId,
        if (itemCount != null) 'item_count': itemCount,
      },
    );
    await _analytics.logPurchase(
      currency: 'XAF',
      value: total,
    );
  }

  static Future<void> logOrderFailed({
    required String errorMessage,
    required String paymentMethod,
    required bool isDelivery,
  }) async {
    await _analytics.logEvent(
      name: 'order_failed',
      parameters: {
        'error_message': errorMessage.length > 100
            ? errorMessage.substring(0, 100)
            : errorMessage,
        'payment_method': paymentMethod,
        'is_delivery': isDelivery.toString(),
      },
    );
  }

  static Future<void> logOrderCancelled({required String orderId}) async {
    await _analytics.logEvent(
      name: 'order_cancelled',
      parameters: {'order_id': orderId},
    );
  }

  // === ÉVÉNEMENTS RESTAURANT ===

  static Future<void> logRestaurantViewed({
    required String restaurantId,
    required String restaurantName,
  }) async {
    await _analytics.logEvent(
      name: 'restaurant_viewed',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
      },
    );
  }

  // === ÉVÉNEMENTS PANIER ===

  static Future<void> logAddToCart({
    required String productId,
    required String productName,
    required double price,
    required int quantity,
    String? restaurantId,
  }) async {
    await _analytics.logAddToCart(
      currency: 'XAF',
      value: price * quantity,
      parameters: {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        if (restaurantId != null) 'restaurant_id': restaurantId,
      },
    );
  }

  static Future<void> logRemoveFromCart({
    required String productId,
    required String productName,
  }) async {
    await _analytics.logRemoveFromCart(
      currency: 'XAF',
      parameters: {
        'product_id': productId,
        'product_name': productName,
      },
    );
  }

  static Future<void> logBeginCheckout({
    required double total,
    required bool isDelivery,
  }) async {
    await _analytics.logBeginCheckout(
      currency: 'XAF',
      value: total,
      parameters: {
        'is_delivery': isDelivery.toString(),
      },
    );
  }

  // === ÉVÉNEMENTS PRODUIT ===

  static Future<void> logProductViewed({
    required String productId,
    required String productName,
    required double price,
  }) async {
    await _analytics.logViewItem(
      currency: 'XAF',
      value: price,
      parameters: {
        'product_id': productId,
        'product_name': productName,
      },
    );
  }

  // === ÉVÉNEMENTS UTILISATEUR ===

  static Future<void> logSignUp({required String method}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> logLogin({required String method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> setUserProperties({
    String? userId,
    String? city,
  }) async {
    if (userId != null) {
      await _analytics.setUserId(id: userId);
    }
    // Propriétés personnalisées
    await _analytics.setUserProperty(name: 'country', value: 'CG');
    await _analytics.setUserProperty(name: 'currency', value: 'XAF');
    if (city != null) {
      await _analytics.setUserProperty(name: 'city', value: city);
    }
  }

  // === ÉVÉNEMENTS NAVIGATION ===

  static Future<void> logSearch({required String searchTerm}) async {
    await _analytics.logSearch(searchTerm: searchTerm);
  }

  static Future<void> logShare({
    required String contentType,
    required String itemId,
  }) async {
    await _analytics.logShare(
      contentType: contentType,
      itemId: itemId,
      method: 'app',
    );
  }

  static Future<void> logFavoriteToggle({
    required String restaurantId,
    required String restaurantName,
    required bool isFavorite,
  }) async {
    await _analytics.logEvent(
      name: isFavorite ? 'add_favorite' : 'remove_favorite',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
      },
    );
  }
}
