// **Un statut que cette version ne connaît pas ne doit pas faire disparaître
// la commande.**
//
// Les trois onglets étaient trois listes blanches disjointes. `_parseStatus`
// rend `OrderStatus.unknow` pour toute valeur inattendue — et `unknow`
// n'appartenait à aucune des trois. La commande s'évaporait de l'application :
// pas d'erreur, pas de compteur, aucune trace. Le jour où le serveur ajoute
// `REMBOURSER` ou `ECHEC`, tout un pan de l'historique part avec.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/presentation/commande_page.dart';
import 'package:lilia_app/models/order.dart';

Order _commande(String id, OrderStatus statut) => Order(
      id: id,
      restaurantId: 'resto-1',
      userId: 'uid-a',
      subTotal: 5000,
      deliveryFee: 1000,
      total: 6750,
      paymentMethod: 'MTN_MOMO',
      status: statut,
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
      restaurant: OrderRestaurant(nom: 'Chez Lilia'),
      items: const [],
    );

class _FausseListe extends UserOrders {
  _FausseListe(this._commandes);
  final List<Order> _commandes;

  @override
  Future<List<Order>> build() async => _commandes;
}

void main() {
  // `main.dart` initialise les données de locale avant `runApp`. Sans elles,
  // le premier `DateFormat('…', 'fr_FR')` de la carte lève une
  // `LocaleDataException` — que `takeException()` avalait : la liste ne se
  // construisait jamais, et le test concluait à tort que la commande avait
  // disparu.
  setUpAll(() => initializeDateFormatting('fr_FR', null));

  test('le serveur peut inventer un statut : le modèle le range en `unknow`', () {
    // Preuve du point de départ : c'est bien ce que produit un statut
    // inattendu, et c'est cette valeur qui tombait dans le vide.
    final ordre = Order.fromJson(<String, dynamic>{
      'id': 'cmd-x',
      'status': 'REMBOURSER',
      'restaurant': <String, dynamic>{'nom': 'X'},
      'items': <dynamic>[],
    });
    expect(ordre.status, OrderStatus.unknow);
  });

  testWidgets('une commande au statut inconnu reste visible', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userOrdersProvider.overrideWith(
            () => _FausseListe([
              _commande('cmd-connue', OrderStatus.enRoute),
              _commande('cmd-inconnue', OrderStatus.unknow),
            ]),
          ),
        ],
        child: const MaterialApp(home: CommandePage()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
    }

    // L'onglet « En cours » est celui affiché par défaut : la commande au
    // statut inconnu y est rangée, avec le repli le moins coûteux — un statut
    // qu'on ne sait pas lire décrit presque toujours une commande vivante.
    expect(
      find.text('Aucune commande en cours'),
      findsNothing,
      reason: 'les deux commandes appartiennent à cet onglet',
    );
    // La liste est paresseuse : la seconde carte peut être hors écran, donc
    // jamais construite. On fait défiler jusqu'à elle plutôt que de conclure
    // à son absence.
    await tester.scrollUntilVisible(
      find.textContaining('Inconnu'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Inconnu'),
      findsWidgets,
      reason:
          '`_getStatusInfo` a toujours su afficher « Inconnu » — mais on '
          'n’arrivait jamais jusqu’à lui, la commande ayant déjà disparu du '
          'filtrage',
    );
  });
}
