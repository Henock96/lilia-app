import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/presentation/widgets/vendor_type_filter_bar.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

/// Puces de filtre par type de vendeur (lot G4, épiceries).
///
/// Une puce n'apparaît que si le catalogue « Tous » contient au moins un
/// vendeur de ce type — c'est ce qui fait apparaître « Épicerie » le jour où la
/// première épicerie est publiée, et jamais vide avant. Aucune requête en
/// plus : la liste est celle que l'accueil charge déjà.
RestaurantSummary _vendor(String id, VendorType type) =>
    RestaurantSummary(id: id, name: 'Boutique $id', address: 'Bacongo', vendorType: type);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Future<List<RestaurantSummary>> Function(VendorType? filter) vendors,
) async {
  final container = ProviderContainer(
    overrides: [
      vendorsListProvider.overrideWith(
        (ref) => vendors(ref.watch(marketplaceFilterProvider)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Column(children: [VendorTypeFilterBar()])),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

/// Libellés des puces affichées, dans l'ordre.
List<String> _chips(WidgetTester tester) => [
      'Tous',
      for (final type in VendorType.values)
        if (find.text(type.label).evaluate().isNotEmpty) type.label,
    ];

void main() {
  testWidgets('une épicerie publiée fait apparaître la puce « Épicerie »', (tester) async {
    await _pump(tester, (_) async => [
          _vendor('r1', VendorType.RESTAURANT),
          _vendor('g1', VendorType.GROCERY),
        ]);

    expect(_chips(tester), ['Tous', 'Restaurant', 'Épicerie']);
  });

  testWidgets('aucune épicerie publiée : pas de puce vide', (tester) async {
    await _pump(tester, (_) async => [
          _vendor('r1', VendorType.RESTAURANT),
          _vendor('b1', VendorType.BAKERY),
        ]);

    expect(_chips(tester), ['Tous', 'Restaurant', 'Boulangerie']);
  });

  testWidgets('catalogue encore en chargement : les puces historiques, sans épicerie', (tester) async {
    await _pump(tester, (_) => Completer<List<RestaurantSummary>>().future);

    expect(_chips(tester), [
      'Tous',
      for (final type in VendorType.marketplaceFilter) type.label,
    ]);
    expect(find.text('Épicerie'), findsNothing);
  });

  testWidgets('la puce sélectionnée reste visible, même si la liste filtrée ne contient qu’elle', (tester) async {
    final container = await _pump(tester, (filter) async => [
          if (filter == null || filter == VendorType.RESTAURANT)
            _vendor('r1', VendorType.RESTAURANT),
          if (filter == null || filter == VendorType.GROCERY)
            _vendor('g1', VendorType.GROCERY),
        ]);

    await tester.tap(find.text('Épicerie'));
    await tester.pump();
    await tester.pump();

    expect(container.read(marketplaceFilterProvider), VendorType.GROCERY);
    // La liste filtrée ne contient plus de restaurant : les puces ne
    // s'appauvrissent pas pour autant, on peut revenir en arrière.
    expect(_chips(tester), ['Tous', 'Restaurant', 'Épicerie']);
  });
}
