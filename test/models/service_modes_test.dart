import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/service_mode_badges.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/service_modes.dart';
import 'package:lilia_app/models/vendor_type.dart';

// Lot 1 — modes de service. Le serveur décide (il relit `supports*` au
// checkout) ; ces tests vérifient seulement que l'app ne propose pas un choix
// voué au refus, et qu'elle lit correctement ce que le serveur publie.

ServiceModes _modes(
  bool delivery,
  bool pickup, {
  VendorType type = VendorType.RESTAURANT,
}) => ServiceModes.of(
  supportsDelivery: delivery,
  supportsPickup: pickup,
  vendorType: type,
);

void main() {
  group('ServiceModes — les trois configurations', () {
    test('livraison seulement', () {
      final m = _modes(true, false);
      expect(m.offers(isDelivery: true), isTrue);
      expect(m.offers(isDelivery: false), isFalse);
      expect(m.resolve(isDelivery: false), isTrue);
    });

    test('retrait seulement : la livraison par défaut bascule sur le retrait', () {
      final m = _modes(false, true);
      expect(m.offers(isDelivery: true), isFalse);
      expect(m.resolve(isDelivery: true), isFalse);
    });

    test('les deux : le choix courant est gardé', () {
      final m = _modes(true, true);
      expect(m.resolve(isDelivery: true), isTrue);
      expect(m.resolve(isDelivery: false), isFalse);
    });

    test('aucun : rien à proposer', () {
      final m = _modes(false, false);
      expect(m.none, isTrue);
      expect(m.resolve(isDelivery: true), isNull);
    });
  });

  group('ServiceModes — HOME_COOK (LIL-131, règle client conservée)', () {
    test('livraison proposée : le retrait reste masqué', () {
      final m = _modes(true, true, type: VendorType.HOME_COOK);
      expect(m.pickup, isFalse);
      expect(m.resolve(isDelivery: false), isTrue);
    });

    test('retrait seul déclaré : il reste proposé, sinon incommandable', () {
      final m = _modes(false, true, type: VendorType.HOME_COOK);
      expect(m.pickup, isTrue);
      expect(m.none, isFalse);
    });
  });

  group('désérialisation', () {
    Map<String, dynamic> json([Map<String, dynamic> extra = const {}]) => {
      'id': 'v1',
      'nom': 'Chez Mode',
      'adresse': 'Moungali',
      ...extra,
    };

    test('valeurs publiées par le serveur', () {
      final r = RestaurantSummary.fromJson(
        json({'supportsDelivery': false, 'supportsPickup': true}),
      );
      expect(r.supportsDelivery, isFalse);
      expect(r.supportsPickup, isTrue);
      final d = Restaurant.fromJson(
        json({'supportsDelivery': true, 'supportsPickup': false}),
      );
      expect(d.serviceModes.delivery, isTrue);
      expect(d.serviceModes.pickup, isFalse);
    });

    test('champs absents (réponse antérieure aux colonnes) : les deux modes',
        () {
      final r = RestaurantSummary.fromJson(json());
      expect(r.supportsDelivery, isTrue);
      expect(r.supportsPickup, isTrue);
      expect(Restaurant.fromJson(json()).serviceModes.none, isFalse);
    });

    test('withProducts conserve les modes', () {
      final d = Restaurant.fromJson(
        json({'supportsDelivery': false, 'supportsPickup': true}),
      ).withProducts(const []);
      expect(d.supportsDelivery, isFalse);
      expect(d.supportsPickup, isTrue);
    });
  });

  group('ServiceModeBadges', () {
    Future<void> pump(WidgetTester tester, ServiceModes modes) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ServiceModeBadges(modes: modes)),
          ),
        );

    testWidgets('livraison seulement', (tester) async {
      await pump(tester, _modes(true, false));
      expect(find.text('Livraison'), findsOneWidget);
      expect(find.text('Retrait sur place'), findsNothing);
    });

    testWidgets('retrait seulement', (tester) async {
      await pump(tester, _modes(false, true));
      expect(find.text('Livraison'), findsNothing);
      expect(find.text('Retrait sur place'), findsOneWidget);
    });

    testWidgets('les deux', (tester) async {
      await pump(tester, _modes(true, true));
      expect(find.text('Livraison'), findsOneWidget);
      expect(find.text('Retrait sur place'), findsOneWidget);
    });
  });
}
