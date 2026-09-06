import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/analytics/analytics_dedupe.dart';
import 'package:lilia_app/analytics/analytics_events.dart';
import 'package:lilia_app/analytics/analytics_sink.dart';
import 'package:lilia_app/analytics/lilia_analytics.dart';
import 'package:lilia_app/services/analytics_service.dart';

/// Horloge pilotée : une garantie temporelle se teste, elle ne s'attend pas.
class _Clock {
  DateTime _t = DateTime(2026, 9, 5, 12);
  DateTime now() => _t;
  void advance(Duration d) => _t = _t.add(d);
}

void main() {
  group('déduplication du bruit de cycle de vie', () {
    test('absorbe les rejeux de build sur restaurant_view', () {
      final sink = RecordingAnalyticsSink();
      final clock = _Clock();
      final a = LiliaAnalytics(sinks: [sink], now: clock.now);

      // Trois reconstructions rapprochées du même écran.
      for (var i = 0; i < 3; i++) {
        a.track(AnalyticsEvents.restaurantView, {
          AnalyticsParams.restaurantId: 'r1',
          AnalyticsParams.restaurantName: 'Chez Lilia',
        });
        clock.advance(const Duration(milliseconds: 40));
      }

      expect(sink.events, hasLength(1));
    });

    test('compte une seconde consultation réelle, plus tard', () {
      final sink = RecordingAnalyticsSink();
      final clock = _Clock();
      final a = LiliaAnalytics(sinks: [sink], now: clock.now);

      a.track(AnalyticsEvents.restaurantView, {
        AnalyticsParams.restaurantId: 'r1',
        AnalyticsParams.restaurantName: 'Chez Lilia',
      });
      // Le client revient sur la fiche après avoir regardé ailleurs.
      clock.advance(const Duration(seconds: 30));
      a.track(AnalyticsEvents.restaurantView, {
        AnalyticsParams.restaurantId: 'r1',
        AnalyticsParams.restaurantName: 'Chez Lilia',
      });

      expect(sink.events, hasLength(2));
    });

    test('ne confond pas deux vendeurs', () {
      final sink = RecordingAnalyticsSink();
      final a = LiliaAnalytics(sinks: [sink], now: _Clock().now);
      a.track(AnalyticsEvents.restaurantView, {
        AnalyticsParams.restaurantId: 'r1',
        AnalyticsParams.restaurantName: 'A',
      });
      a.track(AnalyticsEvents.restaurantView, {
        AnalyticsParams.restaurantId: 'r2',
        AnalyticsParams.restaurantName: 'B',
      });
      expect(sink.events, hasLength(2));
    });

    test("la signature ne dépend pas de l'ordre des clés", () {
      expect(
        analyticsSignature('add_to_cart', {'a': 1, 'b': 2}),
        analyticsSignature('add_to_cart', {'b': 2, 'a': 1}),
      );
    });
  });

  group('unicité métier persistante', () {
    late InMemoryKeyStore store;

    setUp(() => store = InMemoryKeyStore());

    test('order_created ne part qu\'une fois, même après redémarrage', () {
      final first = RecordingAnalyticsSink();
      final a = LiliaAnalytics(sinks: [first], store: store);
      expect(
        a.trackOnce(
          AnalyticsOnceKey.orderCreated('o1'),
          AnalyticsEvents.orderCreated,
          {AnalyticsParams.orderId: 'o1'},
        ),
        isTrue,
      );

      // Redémarrage de l'application : nouvelle instance, même stockage.
      final second = RecordingAnalyticsSink();
      final b = LiliaAnalytics(sinks: [second], store: store);
      expect(
        b.trackOnce(
          AnalyticsOnceKey.orderCreated('o1'),
          AnalyticsEvents.orderCreated,
          {AnalyticsParams.orderId: 'o1'},
        ),
        isFalse,
      );

      expect(first.events, hasLength(1));
      expect(second.events, isEmpty);
    });

    test('payment_success ne part qu\'une fois malgré plusieurs observateurs', () {
      // L'écran d'attente, le détail de la commande et un retour de
      // notification observent tous le même paiement.
      final sink = RecordingAnalyticsSink();
      final a = LiliaAnalytics(sinks: [sink], store: store);
      for (var i = 0; i < 10; i++) {
        a.trackOnce(
          AnalyticsOnceKey.paymentSuccess('pay1'),
          AnalyticsEvents.paymentSuccess,
          {AnalyticsParams.orderId: 'o1'},
        );
      }
      expect(sink.events, hasLength(1));
    });

    test('deux tentatives de paiement sur une même commande comptent deux fois', () {
      final sink = RecordingAnalyticsSink();
      final a = LiliaAnalytics(sinks: [sink], store: store);
      for (final id in ['pay1', 'pay2']) {
        a.trackOnce(
          AnalyticsOnceKey.paymentStarted(id),
          AnalyticsEvents.paymentStarted,
          {AnalyticsParams.orderId: 'o1'},
        );
      }
      expect(sink.events, hasLength(2));
    });

    test('un rejeu de la même tentative ne compte pas deux fois', () {
      // `_createPaymentWithRetry` peut rejouer `POST /payments` : le serveur
      // réutilise la ligne PENDING existante, donc le même `paymentId`.
      final sink = RecordingAnalyticsSink();
      final a = LiliaAnalytics(sinks: [sink], store: store);
      a.trackOnce(
        AnalyticsOnceKey.paymentStarted('pay1'),
        AnalyticsEvents.paymentStarted,
        {AnalyticsParams.orderId: 'o1'},
      );
      a.trackOnce(
        AnalyticsOnceKey.paymentStarted('pay1'),
        AnalyticsEvents.paymentStarted,
        {AnalyticsParams.orderId: 'o1'},
      );
      expect(sink.events, hasLength(1));
    });

    test('borne le nombre de clés conservées', () {
      final registry = OnceRegistry(store, maxKeys: 3);
      for (final k in ['a', 'b', 'c', 'd']) {
        registry.claim(k);
      }
      expect(registry.claim('d'), isFalse, reason: 'récente, toujours connue');
      expect(registry.claim('a'), isTrue, reason: 'la plus ancienne, oubliée');
    });
  });

  group('robustesse', () {
    test("un collecteur en panne n'empêche pas les autres ni ne lève", () {
      final sink = RecordingAnalyticsSink();
      final a = LiliaAnalytics(sinks: [_BrokenSink(), sink]);
      expect(
        () => a.track(AnalyticsEvents.viewCart, {
          AnalyticsParams.itemCount: 1,
          AnalyticsParams.cartTotal: 100,
        }),
        returnsNormally,
      );
      expect(sink.events, hasLength(1));
    });

    test('sans collecteur, track() reste appelable', () {
      final a = LiliaAnalytics(sinks: const []);
      expect(
        () => a.track(AnalyticsEvents.pageView, {
          AnalyticsParams.screenName: 'home',
        }),
        returnsNormally,
      );
    });
  });

  group('identification', () {
    test("transmet l'identifiant interne, et le délie à la déconnexion", () {
      final sink = RecordingAnalyticsSink();
      final a = LiliaAnalytics(sinks: [sink]);
      a.identify('cm4x8k2n0000abcd');
      a.identify(null);
      expect(sink.identified, ['cm4x8k2n0000abcd', null]);
    });
  });

  group('façade AnalyticsService', () {
    late RecordingAnalyticsSink sink;

    setUp(() {
      sink = RecordingAnalyticsSink();
      AnalyticsService.setInstanceForTest(
        LiliaAnalytics(sinks: [sink], store: InMemoryKeyStore()),
      );
    });

    test('trackViewCart ignore un panier vide', () {
      AnalyticsService.trackViewCart(itemCount: 0, cartTotal: 0);
      expect(sink.events, isEmpty);
    });

    test('le tunnel complet part sous les neuf noms officiels', () {
      AnalyticsService.trackRestaurantView(
        restaurantId: 'r1',
        restaurantName: 'Chez Lilia',
      );
      AnalyticsService.trackProductView(
        productId: 'p1',
        productName: 'Poulet braisé',
        restaurantId: 'r1',
        price: 3500,
      );
      AnalyticsService.trackAddToCart(
        productId: 'p1',
        productName: 'Poulet braisé',
        restaurantId: 'r1',
        price: 3500,
        quantity: 1,
      );
      AnalyticsService.trackViewCart(itemCount: 1, cartTotal: 3500);
      AnalyticsService.trackBeginCheckout(itemCount: 1, cartTotal: 3500);
      AnalyticsService.trackOrderCreated(
        orderId: 'o1',
        amount: 4200,
        itemCount: 1,
      );
      AnalyticsService.trackPaymentStarted(
        paymentId: 'pay1',
        orderId: 'o1',
        paymentMethod: 'MTN_MOMO',
        amount: 4200,
      );
      AnalyticsService.trackPaymentSuccess(
        paymentId: 'pay1',
        orderId: 'o1',
        paymentMethod: 'MTN_MOMO',
        amount: 4200,
      );

      expect(sink.names, [
        'restaurant_view',
        'product_view',
        'add_to_cart',
        'view_cart',
        'begin_checkout',
        'order_created',
        'payment_started',
        'payment_success',
      ]);
    });

    test('tout montant du tunnel voyage avec sa devise', () {
      AnalyticsService.trackOrderCreated(
        orderId: 'o1',
        amount: 4200,
        itemCount: 1,
      );
      AnalyticsService.trackPaymentSuccess(
        paymentId: 'pay1',
        orderId: 'o1',
        paymentMethod: 'MTN_MOMO',
        amount: 4200,
      );
      for (final e in sink.events) {
        expect(e.params[AnalyticsParams.currency], 'XAF');
      }
    });

    test('add_to_cart porte bien les cinq paramètres du contrat', () {
      AnalyticsService.trackAddToCart(
        productId: 'p1',
        productName: 'Poulet braisé',
        restaurantId: 'r1',
        price: 3500,
        quantity: 2,
      );
      expect(sink.events.single.params, {
        'product_id': 'p1',
        'product_name': 'Poulet braisé',
        'restaurant_id': 'r1',
        'price': 3500,
        'quantity': 2,
      });
    });

    test('un échec de commande ne transporte aucun message', () {
      AnalyticsService.trackOrderFailed(
        paymentMethod: 'MTN_MOMO',
        failureKind: 'checkout_rejected',
      );
      expect(sink.events.single.params, {
        'payment_method': 'MTN_MOMO',
        'failure_kind': 'checkout_rejected',
      });
    });

    test('un paiement échoué ne produit pas payment_success', () {
      AnalyticsService.trackPaymentStarted(
        paymentId: 'pay1',
        orderId: 'o1',
        paymentMethod: 'MTN_MOMO',
        amount: 4200,
      );
      AnalyticsService.trackPaymentFailed(
        orderId: 'o1',
        paymentMethod: 'MTN_MOMO',
        failureKind: 'cancelled',
      );
      expect(sink.names, ['payment_started', 'payment_failed']);
      expect(sink.names, isNot(contains('payment_success')));
    });
  });
}

class _BrokenSink implements AnalyticsSink {
  @override
  String get name => 'broken';

  @override
  void event(String name, Map<String, Object> params) =>
      throw StateError('réseau coupé');

  @override
  void identify(String? userId) => throw StateError('réseau coupé');
}
