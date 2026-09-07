import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/models/location_precision.dart';
import 'package:lilia_app/models/order.dart';

/// Destination d'une commande, côté client.
///
/// ## Ce que ces tests verrouillent
///
/// La règle de la plateforme : `latitude + longitude` **n'est pas** l'adresse
/// de livraison. Une commande porte les deux, et l'une ne remplace jamais
/// l'autre — un texte lisible par un humain, un point exploitable par une
/// machine, et un niveau de fiabilité qui dit s'il faut y croire.
///
/// ## Ce qu'ils refusent explicitement
///
/// Un repli vers une relation `adresse` imbriquée. `Order` n'en a pas côté
/// serveur, et c'est délibéré : les six champs `delivery*` sont un
/// **instantané** figé au checkout. Si le client corrige son adresse le
/// lendemain, la commande d'hier garde la destination qui a été livrée. Aller
/// rechercher l'adresse vivante ressusciterait précisément l'ambiguïté que le
/// snapshot supprime.
Map<String, dynamic> _orderJson({
  Object? deliveryLatitude,
  Object? deliveryLongitude,
  Object? deliveryPrecision,
  Object? deliveryLandmark,
  Object? deliveryAddress = 'Avenue de la Paix, Moungali, Brazzaville',
}) => <String, dynamic>{
  'id': 'ord_123',
  'userId': 'usr_456',
  'restaurantId': 'rest_789',
  'total': 7500,
  'status': 'EN_ROUTE',
  'createdAt': '2026-09-07T18:00:00.000Z',
  'updatedAt': '2026-09-07T18:30:00.000Z',
  'isDelivery': true,
  'paymentMethod': 'MTN_MOMO',
  'items': <Map<String, dynamic>>[],
  'restaurant': <String, dynamic>{'nom': 'Chez Mado'},
  'deliveryAddress': deliveryAddress,
  'deliveryLatitude': deliveryLatitude,
  'deliveryLongitude': deliveryLongitude,
  'deliveryPrecision': deliveryPrecision,
  'deliveryLandmark': deliveryLandmark,
  'notes': 'Sonner à la barrière noire',
  'contactPhone': '+242065000000',
};

void main() {
  group('LocationPrecision — miroir de l\'enum Prisma', () {
    test('parse les trois valeurs du backend', () {
      expect(LocationPrecision.fromWire('EXACT'), LocationPrecision.exact);
      expect(
        LocationPrecision.fromWire('APPROXIMATE'),
        LocationPrecision.approximate,
      );
      expect(LocationPrecision.fromWire('UNKNOWN'), LocationPrecision.unknown);
    });

    test('toute valeur inattendue retombe sur unknown, jamais sur une position',
        () {
      // Le repli doit faire **taire** la carte, pas la faire mentir. Retomber
      // sur « centroïde du quartier » afficherait un point que personne n'a
      // posé, et le livreur s'y rendrait.
      expect(LocationPrecision.fromWire(null), LocationPrecision.unknown);
      expect(LocationPrecision.fromWire(''), LocationPrecision.unknown);
      expect(LocationPrecision.fromWire('exact'), LocationPrecision.unknown);
      expect(
        LocationPrecision.fromWire('QUARTIER_CENTER'),
        LocationPrecision.unknown,
      );
    });
  });

  group('Order — destination', () {
    test('conserve ensemble l\'adresse humaine, le point et les repères', () {
      final order = Order.fromJson(
        _orderJson(
          deliveryLatitude: -4.2634,
          deliveryLongitude: 15.2429,
          deliveryPrecision: 'EXACT',
          deliveryLandmark: 'En face de la pharmacie du Centre',
        ),
      );

      expect(order.deliveryAddress, 'Avenue de la Paix, Moungali, Brazzaville');
      expect(order.deliveryLatitude, -4.2634);
      expect(order.deliveryLongitude, 15.2429);
      expect(order.deliveryPrecision, LocationPrecision.exact);
      expect(order.deliveryLandmark, 'En face de la pharmacie du Centre');
      expect(order.notes, 'Sonner à la barrière noire');
      expect(order.contactPhone, '+242065000000');
      expect(order.hasDeliveryCoordinates, isTrue);
      expect(order.deliveryNeedsWarning, isFalse);
    });

    test('une position de quartier est utilisable mais signalée', () {
      final order = Order.fromJson(
        _orderJson(
          deliveryLatitude: -4.2800,
          deliveryLongitude: 15.2600,
          deliveryPrecision: 'APPROXIMATE',
        ),
      );

      expect(order.hasDeliveryCoordinates, isTrue);
      expect(order.deliveryNeedsWarning, isTrue);
    });

    test('sans coordonnées, aucun marqueur — mais l\'adresse reste lisible',
        () {
      final order = Order.fromJson(_orderJson(deliveryPrecision: 'UNKNOWN'));

      expect(order.hasDeliveryCoordinates, isFalse);
      expect(order.deliveryAddress, isNotNull);
      expect(order.deliveryDescription, isNotNull);
    });

    test(
      'des coordonnées résiduelles ne suffisent pas si la précision est unknown',
      () {
        // Le serveur qualifie la destination ; une paire de nombres restée en
        // base ne doit pas passer par-dessus son verdict.
        final order = Order.fromJson(
          _orderJson(
            deliveryLatitude: -4.2634,
            deliveryLongitude: 15.2429,
            deliveryPrecision: 'UNKNOWN',
          ),
        );

        expect(order.hasDeliveryCoordinates, isFalse);
      },
    );

    test('la description joint l\'adresse et les repères sans les confondre',
        () {
      final order = Order.fromJson(
        _orderJson(deliveryLandmark: 'Portail bleu'),
      );

      expect(
        order.deliveryDescription,
        'Avenue de la Paix, Moungali, Brazzaville — Portail bleu',
      );
    });

    test('en mode retrait, il n\'y a ni adresse ni description', () {
      final order = Order.fromJson(_orderJson(deliveryAddress: null));

      expect(order.deliveryAddress, isNull);
      expect(order.deliveryDescription, isNull);
      expect(order.hasDeliveryCoordinates, isFalse);
    });
  });
}
