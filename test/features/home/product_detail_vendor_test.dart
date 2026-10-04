// La fiche produit n'affichait jamais son vendeur. Ces tests fixent d'où vient
// le nom — et qu'aucun nom n'est inventé quand il n'est pas connu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/presentation/product_detail_page.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

Product _produit({String? vendeur, VendorType? type}) => Product(
  id: 'prod-1',
  name: 'Poulet braisé',
  description: 'Avec du piment',
  prixOriginal: 5000,
  restaurantId: 'resto-1',
  variants: const [],
  restaurantName: vendeur,
  restaurantVendorType: type,
);

Future<void> _monter(
  WidgetTester tester,
  Product produit, {
  required Future<Restaurant> Function() fiche,
}) async {
  tester.view.physicalSize = const Size(1400, 3000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productByIdProvider('prod-1').overrideWith((ref) async => produit),
        restaurantControllerProvider('resto-1').overrideWith((ref) => fiche()),
      ],
      child: MaterialApp(
        home: ProductDetailPage(productId: 'prod-1', product: produit),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();
  }
}

Restaurant _fiche() => Restaurant(
  id: 'resto-1',
  name: 'Chez Mama Ngouabi',
  address: 'Brazzaville',
  products: const [],
  categoriesMap: const {},
  vendorType: VendorType.HOME_COOK,
);

void main() {
  testWidgets('nom embarqué dans la réponse produit', (tester) async {
    var lectures = 0;
    await _monter(
      tester,
      _produit(vendeur: 'Le First Restaurant', type: VendorType.RESTAURANT),
      fiche: () async {
        lectures++;
        return _fiche();
      },
    );
    expect(find.textContaining('Le First Restaurant'), findsOneWidget);
    expect(lectures, 0, reason: 'le nom est déjà là : aucun appel en plus');
  });

  testWidgets('produit lu depuis /vendors/:id : repli sur la fiche vendeur', (
    tester,
  ) async {
    await _monter(tester, _produit(), fiche: () async => _fiche());
    expect(find.textContaining('Chez Mama Ngouabi'), findsOneWidget);
    expect(find.textContaining('Cuisine maison'), findsOneWidget);
  });

  testWidgets('aucun nom réel connu : pas de ligne vendeur générique', (
    tester,
  ) async {
    await _monter(
      tester,
      _produit(),
      fiche: () async => throw Exception('hors ligne'),
    );
    expect(find.textContaining('par '), findsNothing);
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
  });
}
