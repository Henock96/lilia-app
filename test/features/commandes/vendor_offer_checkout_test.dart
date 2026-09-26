import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lilia_app/common_widgets/offer_badge.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/models/active_offer.dart';
import 'package:lilia_app/models/checkout_quote.dart';
import 'package:lilia_app/models/restaurant.dart';

/// F3-11 — offre boutique côté client : badge, devis serveur, offre vue
/// renvoyée au checkout. Réponses modelées sur `OrderCheckoutService.quote`.
Map<String, dynamic> _quoteBody() => {
      'data': {
        'restaurantId': 'v1',
        'subTotal': 5000,
        'deliveryFee': 1000,
        'deliveryFeeBeforePromo': 1000,
        'serviceFee': 750,
        'vendorOffer': {
          'id': 'o1',
          'kind': 'PERCENT',
          'value': 10,
          'label': '−10 % sur toute la boutique',
          'discountXaf': 500,
        },
        'promo': null,
        'loyalty': {'pointsUsed': 0, 'discountXaf': 0},
        'total': 6250,
      },
    };

Map<String, dynamic> _checkoutReply() => {
      'message': 'Commande créée avec succès.',
      'data': {
        'id': 'c1',
        'restaurantId': 'v1',
        'userId': 'u1',
        'subTotal': 5000,
        'deliveryFee': 1000,
        'total': 6250,
        'paymentMethod': 'MTN_MOMO',
        'status': 'EN_ATTENTE',
        'createdAt': '2026-09-26T10:00:00.000Z',
        'updatedAt': '2026-09-26T10:00:00.000Z',
        'items': <dynamic>[],
      },
    };

void main() {
  late ApiClient client;
  late DioAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    client = ApiClient.test(
      baseUrl: 'https://test.local',
      tokenProvider: () async => 'tok',
      forceRefreshToken: () async => 'tok2',
    );
    adapter = DioAdapter(dio: client.dio);
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
  });
  tearDown(() => container.dispose());

  OrderRepository repo() => container.read(orderRepositoryProvider.notifier);

  group('modèles', () {
    test('activeOffer : badge court, libellé serveur ; absent = null', () {
      final offer = ActiveOffer.tryParse({
        'id': 'o1',
        'kind': 'PERCENT',
        'value': 10,
        'label': '−10 % sur toute la boutique',
      })!;
      expect(offer.badge, '−10 %');
      expect(ActiveOffer.tryParse(null), isNull);
      expect(ActiveOffer.tryParse({'id': 'o1'}), isNull);

      final summary = RestaurantSummary.fromJson({
        'id': 'v1',
        'nom': 'Chez Maman',
        'adresse': 'Bacongo',
        'activeOffer': {'id': 'o1', 'kind': 'FIXED_THRESHOLD', 'value': 500},
      });
      expect(summary.activeOffer?.badge, '−500 F');
    });

    test('devis : chaque ligne lue, offre comprise', () {
      final q = CheckoutQuote.fromJson(
        _quoteBody()['data'] as Map<String, dynamic>,
      );
      expect(q.total, 6250);
      expect(q.serviceFee, 750);
      expect(q.vendorOffer?.id, 'o1');
      expect(q.vendorOffer?.discount, 500);
    });
  });

  group('OrderRepository', () {
    test('devis d’une adresse pas encore enregistrée : le quartier suffit', () async {
      adapter.onPost(
        '/orders/quote',
        (s) => s.reply(200, _quoteBody()),
        data: {'isDelivery': true, 'quartierId': 'q1'},
      );
      final q = await repo().quote(isDelivery: true, quartierId: 'q1');
      expect(q.total, 6250);
    });

    test('devis d’une adresse enregistrée : l’adresse fait foi', () async {
      adapter.onPost(
        '/orders/quote',
        (s) => s.reply(200, _quoteBody()),
        data: {'isDelivery': true, 'adresseId': 'a1'},
      );
      final q = await repo().quote(
        isDelivery: true,
        adresseId: 'a1',
        quartierId: 'q1',
      );
      expect(q.vendorOffer?.id, 'o1');
    });

    test('checkout : l’offre vue part, « aucune » part en null', () async {
      adapter.onPost(
        '/orders/checkout',
        (s) => s.reply(201, _checkoutReply()),
        data: {
          'paymentMethod': 'MTN_MOMO',
          'isDelivery': false,
          'vendorOfferId': 'o1',
        },
      );
      await repo().createOrders(
        paymentMethod: 'MTN_MOMO',
        isDelivery: false,
        seenVendorOffer: (id: 'o1'),
      );

      adapter.onPost(
        '/orders/checkout',
        (s) => s.reply(201, _checkoutReply()),
        data: {
          'paymentMethod': 'MTN_MOMO',
          'isDelivery': false,
          'vendorOfferId': null,
        },
      );
      await repo().createOrders(
        paymentMethod: 'MTN_MOMO',
        isDelivery: false,
        seenVendorOffer: (id: null),
      );
    });

    test('checkout sans devis : aucune affirmation sur l’offre', () async {
      adapter.onPost(
        '/orders/checkout',
        (s) => s.reply(201, _checkoutReply()),
        data: {'paymentMethod': 'MTN_MOMO', 'isDelivery': false},
      );
      final order = await repo().createOrders(
        paymentMethod: 'MTN_MOMO',
        isDelivery: false,
      );
      expect(order.id, 'c1');
    });
  });

  testWidgets('badge : montant court, libellé complet en mode étendu', (
    tester,
  ) async {
    const offer = ActiveOffer(
      id: 'o1',
      kind: 'PERCENT',
      value: 10,
      label: '−10 % sur toute la boutique',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OfferBadge(offer: offer),
              OfferBadge(offer: offer, expanded: true),
            ],
          ),
        ),
      ),
    );
    expect(find.text('−10 %'), findsOneWidget);
    expect(find.text('−10 % sur toute la boutique'), findsOneWidget);
  });
}
