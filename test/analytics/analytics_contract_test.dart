import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/analytics/analytics_events.dart';
import 'package:lilia_app/analytics/analytics_sanitizer.dart';

/// Tests du contrat et du désinfecteur.
///
/// Ils sont le miroir Dart de `lilia-food-web/apps/web/lib/analytics/
/// sanitize.test.ts`. Les deux vérifient les mêmes règles sur les mêmes
/// données : c'est ce qui rend crédible l'affirmation « les trois plateformes
/// envoient la même chose ».
void main() {
  const sanitizer = AnalyticsSanitizer();

  group('liste blanche', () {
    test('laisse passer les paramètres du contrat', () {
      final r = sanitizer.sanitize(AnalyticsEvents.addToCart, {
        AnalyticsParams.productId: 'p1',
        AnalyticsParams.productName: 'Poulet braisé',
        AnalyticsParams.restaurantId: 'r1',
        AnalyticsParams.price: 3500,
        AnalyticsParams.quantity: 2,
      });
      expect(r.params, {
        'product_id': 'p1',
        'product_name': 'Poulet braisé',
        'restaurant_id': 'r1',
        'price': 3500,
        'quantity': 2,
      });
      expect(r.dropped, isEmpty);
    });

    test('retire tout paramètre non déclaré, même anodin', () {
      final r = sanitizer.sanitize(AnalyticsEvents.viewCart, {
        AnalyticsParams.itemCount: 3,
        AnalyticsParams.cartTotal: 12000,
        'vendor_type': 'BAKERY',
        'is_delivery': true,
      });
      expect(r.params, {'item_count': 3, 'cart_total': 12000});
      expect(r.dropped.map((d) => d.key), containsAll(['vendor_type', 'is_delivery']));
    });

    test("n'accepte ni objet ni liste — un objet aplati échapperait au contrôle", () {
      final r = sanitizer.sanitize(AnalyticsEvents.restaurantView, {
        AnalyticsParams.restaurantId: 'r1',
        AnalyticsParams.restaurantName: {'nom': 'Chez Lilia'},
      });
      expect(r.params, {'restaurant_id': 'r1'});
    });

    test('écarte NaN et infini, qui produisent des agrégats faux', () {
      final r = sanitizer.sanitize(AnalyticsEvents.viewCart, {
        AnalyticsParams.itemCount: double.nan,
        AnalyticsParams.cartTotal: double.infinity,
      });
      expect(r.params, isEmpty);
    });

    test('tronque les textes trop longs', () {
      final r = sanitizer.sanitize(AnalyticsEvents.productView, {
        AnalyticsParams.productName: 'a' * 500,
      });
      expect(
        (r.params[AnalyticsParams.productName] as String).length,
        analyticsMaxStringLength,
      );
    });

    test('un événement inconnu ne laisse rien passer', () {
      final r = sanitizer.sanitize('restaurant_opened', {
        AnalyticsParams.restaurantId: 'r1',
      });
      expect(r.params, isEmpty);
    });
  });

  group('absence de données personnelles', () {
    final pii = <String, Object?>{
      'contact_phone': '+242 06 123 45 67',
      'phone': '066123456',
      'telephone': '066123456',
      'email': 'client@example.cg',
      'password': 'hunter2',
      'firebase_token': 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjEyMyJ9.eyJzdWIiOiJhIn0.sig',
      'idToken': 'abc',
      'latitude': -4.2634,
      'longitude': 15.2429,
      'deliveryLatitude': -4.2634,
      'deliveryLongitude': 15.2429,
      'deliveryAddress': 'Rue Mfilou, face pharmacie',
      'adresse': 'Avenue de la Paix',
      'landmark': 'portail bleu',
      'notes': 'sans piment',
      'momoNumber': '066123456',
      'card': '4111111111111111',
      'iban': 'CG00000000000000',
      'searchTerm': 'poulet braisé',
      'query': 'poulet',
      'errorMessage': 'Airtel_CG did not specify a reason',
    };

    for (final event in AnalyticsEvents.funnel) {
      test('$event ne laisse passer aucune donnée personnelle', () {
        expect(sanitizer.sanitize(event, pii).params, isEmpty);
      });
    }

    test('rejette une clé interdite, y compris en casse chameau', () {
      expect(AnalyticsSanitizer.isForbiddenKey('contact_phone'), isTrue);
      expect(AnalyticsSanitizer.isForbiddenKey('deliveryLatitude'), isTrue);
      expect(AnalyticsSanitizer.isForbiddenKey('idToken'), isTrue);
      expect(AnalyticsSanitizer.isForbiddenKey('errorMessage'), isTrue);
    });

    test("ne confond pas un montant avec un téléphone ('total' contient 'tel')", () {
      expect(AnalyticsSanitizer.isForbiddenKey('cart_total'), isFalse);
      expect(AnalyticsSanitizer.isForbiddenKey('item_count'), isFalse);
      expect(AnalyticsSanitizer.isForbiddenKey('payment_method'), isFalse);
      expect(AnalyticsSanitizer.isForbiddenKey('restaurant_name'), isFalse);
      expect(AnalyticsSanitizer.isForbiddenKey('amount'), isFalse);
    });

    test('rejette une valeur personnelle rangée sous une clé autorisée', () {
      // Le cas réel : un vendeur met son numéro dans le nom du produit.
      final r = sanitizer.sanitize(AnalyticsEvents.productView, {
        AnalyticsParams.productId: 'p1',
        AnalyticsParams.productName: 'Commandez au 06 123 45 67',
      });
      expect(r.params, {'product_id': 'p1'});
      expect(r.dropped.single.reason, DropReason.piiValue);
    });

    test('reconnaît les formes personnelles usuelles', () {
      expect(AnalyticsSanitizer.looksLikePii('+242061234567'), isTrue);
      expect(AnalyticsSanitizer.looksLikePii('06 123 45 67'), isTrue);
      expect(AnalyticsSanitizer.looksLikePii('client@lilia.cg'), isTrue);
      expect(AnalyticsSanitizer.looksLikePii('Poulet braisé'), isFalse);
      expect(AnalyticsSanitizer.looksLikePii('cm4x8k2n0000abcd'), isFalse);
      expect(AnalyticsSanitizer.looksLikePii('MTN_MOMO'), isFalse);
    });
  });

  group('cohérence du contrat', () {
    test('les neuf événements du tunnel sont déclarés, dans l\'ordre', () {
      expect(AnalyticsEvents.funnel, [
        'page_view',
        'restaurant_view',
        'product_view',
        'add_to_cart',
        'view_cart',
        'begin_checkout',
        'payment_started',
        'payment_success',
        'order_created',
      ]);
    });

    test('les paramètres correspondent au contrat officiel', () {
      expect(analyticsEventParams['restaurant_view'], [
        'restaurant_id',
        'restaurant_name',
      ]);
      expect(analyticsEventParams['product_view'], [
        'product_id',
        'product_name',
        'restaurant_id',
        'price',
      ]);
      expect(analyticsEventParams['add_to_cart'], [
        'product_id',
        'product_name',
        'restaurant_id',
        'price',
        'quantity',
      ]);
      expect(analyticsEventParams['view_cart'], ['item_count', 'cart_total']);
      expect(analyticsEventParams['begin_checkout'], ['item_count', 'cart_total']);
      expect(analyticsEventParams['payment_started'], [
        'order_id',
        'payment_method',
        'amount',
        'currency',
      ]);
      expect(analyticsEventParams['payment_success'], [
        'order_id',
        'payment_method',
        'amount',
        'currency',
      ]);
      expect(analyticsEventParams['order_created'], [
        'order_id',
        'amount',
        'currency',
        'item_count',
      ]);
    });

    test("aucune variante de nom d'événement n'est déclarée", () {
      const forbidden = [
        'restaurant_open',
        'restaurant_opened',
        'view_restaurant',
        'restaurant_clicked',
        'restaurant_viewed',
        'add_to_cart_from_home',
        'popular_dish_tap',
        'popular_restaurant_tap',
        'recommendation_tap',
        'vendor_view',
      ];
      for (final name in forbidden) {
        expect(analyticsEventParams.containsKey(name), isFalse, reason: name);
      }
    });

    test('la devise est le franc CFA', () {
      expect(analyticsCurrency, 'XAF');
    });
  });
}
