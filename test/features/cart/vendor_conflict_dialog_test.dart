// P3-13 — panier d'une autre boutique : une modale qui propose le geste, au
// lieu d'un message d'erreur sans action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/theme/app_theme.dart';

/// Panier d'un autre vendeur (`resto-A`), qui consigne vidages et ajouts.
class _PanierAutreBoutique extends CartController {
  final List<String> journal = [];

  @override
  Future<Cart?> build() async => Cart(
    id: 'c1',
    userId: 'u1',
    createdAt: DateTime(2026, 9, 29),
    updatedAt: DateTime(2026, 9, 29),
    items: [
      CartItem(
        id: 'i1',
        cartId: 'c1',
        productId: 'p-a',
        variantId: 'v-a',
        quantite: 1,
        createdAt: DateTime(2026, 9, 29),
        product: ProductItem(nom: 'Pain', restaurantId: 'resto-A'),
        variant: VariantItem(label: 'Normal', prix: 500),
      ),
    ],
  );

  @override
  Future<void> clearCart() async => journal.add('vider');

  @override
  Future<void> addItem({
    required String variantId,
    int quantity = 1,
    CartItemPreview? preview,
    bool awaitServer = false,
  }) async => journal.add('ajout $variantId');
}

final _poulet = Product(
  id: 'poulet',
  name: 'Poulet braisé',
  description: '',
  prixOriginal: 6000,
  restaurantId: 'resto-B',
  variants: [ProductVariant(id: 'entier', label: 'Entier', prix: 6000)],
);

void main() {
  late _PanierAutreBoutique panier;

  Future<void> monter(WidgetTester tester, {bool ficheEnCache = true}) async {
    panier = _PanierAutreBoutique();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartControllerProvider.overrideWith(() => panier),
          restaurantControllerProvider('resto-A').overrideWith(
            (ref) async => Restaurant(
              id: 'resto-A',
              name: 'Boulangerie Awa',
              address: 'Brazzaville',
              products: const [],
              categoriesMap: const {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          // En production, la coque de navigation (badge panier) observe le
          // panier : il est chargé quand le client tape « + ».
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(cartControllerProvider);
              // La fiche vendeur est en cache quand le client l'a visitée.
              if (ficheEnCache) {
                ref.watch(restaurantControllerProvider('resto-A'));
              }
              return Scaffold(
                body: Center(child: QuickAddButton(product: _poulet)),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('la modale nomme la boutique et ne vide rien sans accord', (
    tester,
  ) async {
    await monter(tester);
    await tester.tap(find.byType(QuickAddButton));
    await tester.pumpAndSettle();

    expect(find.text('Changer de boutique ?'), findsOneWidget);
    expect(find.textContaining('Boulangerie Awa'), findsOneWidget);

    await tester.tap(find.text('Garder mon panier'));
    await tester.pumpAndSettle();
    expect(panier.journal, isEmpty);
  });

  testWidgets('fiche non chargée : message générique, pas d\'attente réseau', (
    tester,
  ) async {
    await monter(tester, ficheEnCache: false);
    await tester.tap(find.byType(QuickAddButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('d\'une autre boutique'), findsOneWidget);
  });

  testWidgets('« Vider et ajouter » : vide, puis ajoute', (tester) async {
    await monter(tester);
    await tester.tap(find.byType(QuickAddButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vider et ajouter'));
    await tester.pumpAndSettle();
    expect(panier.journal, ['vider', 'ajout entier']);
  });
}
