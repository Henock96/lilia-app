import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/pickup_card.dart';
import 'package:lilia_app/features/reservations/data/reservation_repository.dart';
import 'package:lilia_app/features/reservations/presentation/reservation_providers.dart';
import 'package:lilia_app/features/reservations/presentation/reservation_screens.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/order.dart';

/// Lot 4 (4D) — l'app client affiche le verdict serveur (`allowedActions`),
/// la politique servie, et guide la précommande (D-3) et le code (D-2).
Map<String, dynamic> _data(String name) =>
    (jsonDecode(
              File(
                'test/features/reservations/fixtures/$name.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>)['data']
        as Map<String, dynamic>;

Cart _cart(List<String> restaurantIds) => Cart(
  id: 'panier-1',
  userId: 'uid-a',
  createdAt: DateTime(2026, 11, 20),
  updatedAt: DateTime(2026, 11, 20),
  items: [
    for (final (i, rid) in restaurantIds.indexed)
      CartItem(
        id: 'ligne-$i',
        cartId: 'panier-1',
        productId: 'prod-$i',
        variantId: 'var-$i',
        quantite: 2,
        createdAt: DateTime(2026, 11, 20),
        product: ProductItem(nom: 'Poulet DG', restaurantId: rid),
        variant: VariantItem(label: 'Normal', prix: 5000),
      ),
  ],
);

class _FauxPanier extends CartController {
  _FauxPanier(this.cart);

  final Cart? cart;

  @override
  Future<Cart?> build() async => cart;
}

Future<void> _pumpView(
  WidgetTester tester,
  ClientReservation r, {
  void Function(String)? onOpenOrder,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: ClientReservationView(
        r: r,
        busy: false,
        onCancel: () {},
        onOpenOrder: onOpenOrder ?? (_) {},
      ),
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('précommande = panier serveur (D-3)', () {
    test('panier vide, autre vendeur, prêt', () {
      expect(reservationCartState(null, 'v1'), ReservationCartState.empty);
      expect(
        reservationCartState(_cart(['v1', 'v2']), 'v1'),
        ReservationCartState.otherVendor,
      );
      expect(
        reservationCartState(_cart(['v1', 'v1']), 'v1'),
        ReservationCartState.ready,
      );
    });

    test('jours proposés : bornes serveur, 14 au plus', () {
      final days = reservationDays(
        const ReservationAvailability(
          maxPartySize: 8,
          firstDate: '2026-11-20',
          lastDate: '2026-12-20',
        ),
      );
      expect(days.length, 14);
      expect(days.first, DateTime.utc(2026, 11, 20));
      expect(days.last, DateTime.utc(2026, 12, 3));
    });

    Future<void> pumpBooking(WidgetTester tester, Cart? cart) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartControllerProvider.overrideWith(() => _FauxPanier(cart)),
              reservationBoundsProvider.overrideWith(
                (ref, id) async => const ReservationAvailability(
                  maxPartySize: 8,
                  firstDate: '2026-11-20',
                  lastDate: '2026-12-20',
                ),
              ),
            ],
            child: const MaterialApp(
              home: ReservationBookingPage(restaurantId: 'v1'),
            ),
          ),
        );

    testWidgets('panier vide : invite à choisir ses plats, pas de créneau', (
      tester,
    ) async {
      await pumpBooking(tester, null);
      await tester.pump();
      expect(find.text('Choisir mes plats'), findsOneWidget);
      expect(find.text('Nombre de personnes'), findsNothing);
      expect(find.byKey(const Key('reservation-send')), findsNothing);
    });

    testWidgets('panier d’un autre établissement : proposer de le vider', (
      tester,
    ) async {
      await pumpBooking(tester, _cart(['v2']));
      await tester.pump();
      expect(find.text('Vider le panier'), findsOneWidget);
      expect(find.byKey(const Key('reservation-send')), findsNothing);
    });

    testWidgets('panier de ce restaurant : récapitulatif et choix du créneau', (
      tester,
    ) async {
      await pumpBooking(tester, _cart(['v1']));
      await tester.pump();
      expect(find.text('2 × Poulet DG'), findsOneWidget);
      expect(find.textContaining('deviennent votre précommande'), findsOne);
      expect(find.text('Nombre de personnes'), findsOneWidget);
      // Le choix du jour défile aussi (horizontalement) : viser la page.
      await tester.scrollUntilVisible(
        find.byKey(const Key('reservation-send')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final send = tester.widget<FilledButton>(
        find.byKey(const Key('reservation-send')),
      );
      expect(send.onPressed, isNull, reason: 'aucun créneau choisi');
    });
  });

  group('fiche réservation', () {
    testWidgets('acceptée : payer (commande liée) ou annuler, délai affiché', (
      tester,
    ) async {
      String? opened;
      final r = ClientReservation.fromJson(
        _data('client_get_awaiting_payment'),
      );
      await _pumpView(tester, r, onOpenOrder: (id) => opened = id);

      expect(find.text('Acceptée — à payer'), findsOneWidget);
      expect(find.textContaining('Payez votre précommande avant'), findsOne);
      await tester.scrollUntilVisible(
        find.byKey(const Key('reservation-pay')),
        200,
      );
      expect(find.textContaining('pas remboursée'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reservation-pay')));
      expect(opened, r.payment!.orderId);
      await tester.scrollUntilVisible(
        find.byKey(const Key('reservation-cancel')),
        200,
      );
      expect(find.byKey(const Key('reservation-cancel')), findsOneWidget);
    });

    testWidgets('confirmée : le code d’arrivée vient de la commande (D-2)', (
      tester,
    ) async {
      final r = ClientReservation.fromJson({
        ..._data('client_get_awaiting_payment'),
        'status': 'CONFIRMED',
        'allowedActions': ['cancel'],
      });
      await _pumpView(tester, r);
      expect(find.textContaining('code d’arrivée'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const Key('reservation-open-order')),
        200,
      );
      expect(find.byKey(const Key('reservation-pay')), findsNothing);
    });

    testWidgets('honorée : aucun geste', (tester) async {
      await _pumpView(
        tester,
        ClientReservation.fromJson(_data('client_get_honored')),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      expect(find.byKey(const Key('reservation-pay')), findsNothing);
      expect(find.byKey(const Key('reservation-cancel')), findsNothing);
    });
  });

  group('commande liée (F-6, D-2)', () {
    final linked = Order.fromJson(_data('client_linked_order_ready'));

    test('reservationId lu, aucun geste publié sur la commande', () {
      expect(linked.isReservation, isTrue);
      expect(linked.allowedActions, isEmpty);
      expect(linked.canConfirmPickup, isFalse);
    });

    testWidgets('carte de retrait : « Votre table est prête » et le code', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PickupCard(
              order: linked,
              onConfirm: () async => linked,
              onConfirmed: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Votre table est prête — code d’arrivée'), findsOne);
      expect(find.text(linked.pickupCode!), findsOneWidget);
      expect(find.textContaining('confirme votre arrivée'), findsOneWidget);
    });

    testWidgets('bandeau vers la réservation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReservationOrderBanner(reservationId: 'r1')),
        ),
      );
      expect(find.text('Précommande de votre réservation'), findsOneWidget);
    });
  });
}
