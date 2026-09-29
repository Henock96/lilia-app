// P3-01 — un produit d'une boutique fermée ne doit jamais s'afficher
// « Disponible » avec un « + » actif.
//
// Trois états de `restaurantIsOpen` : `true` (ouverte), `false` (fermée,
// bloquant) et `null` (inconnu : **pas** de blocage, le serveur arbitre au
// panier et au checkout).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';
import 'package:lilia_app/features/home/presentation/widgets/product_availability_badge.dart';
import 'package:lilia_app/features/home/presentation/widgets/vendor_product_card.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/theme/app_theme.dart';

Product _produit({bool? open, int? stockRestant, bool isAvailable = true}) =>
    Product(
      id: 'p1',
      name: 'Poulet braisé',
      description: '',
      prixOriginal: 6000,
      restaurantId: 'r1',
      restaurantName: 'Chez Mama',
      restaurantIsOpen: open,
      stockRestant: stockRestant,
      isAvailable: isAvailable,
      variants: [ProductVariant(id: 'v1', label: 'Entier', prix: 6000)],
    );

Future<void> _monter(WidgetTester tester, Widget child) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ListView(children: [child])),
    ),
  ),
);

void main() {
  group('Product.unavailability — la boutique', () {
    test('ouverte : commandable', () {
      expect(_produit(open: true).unavailability, isNull);
      expect(_produit(open: true).isOrderable, isTrue);
    });

    test('fermée : non commandable, même en stock', () {
      final p = _produit(open: false, stockRestant: 10);
      expect(p.unavailability, ProductUnavailability.boutiqueFermee);
      expect(p.isOrderable, isFalse);
    });

    test('inconnue (null) : pas de blocage côté client', () {
      expect(_produit(open: null).unavailability, isNull);
      expect(_produit(open: null).isOrderable, isTrue);
    });

    test('fermée prime sur épuisé : la conduite à tenir est « revenir »', () {
      expect(
        _produit(open: false, stockRestant: 0).unavailability,
        ProductUnavailability.boutiqueFermee,
      );
    });

    test(
      'fermée : ajout rapide refusé avec un message qui nomme la boutique',
      () {
        final p = _produit(open: false);
        expect(quickAddActionFor(p), QuickAddAction.unavailable);
        expect(quickAddUnavailableMessage(p), contains('Chez Mama'));
        expect(quickAddUnavailableMessage(p), contains('fermée'));
      },
    );

    test('inconnue : ajout rapide autorisé', () {
      expect(
        quickAddActionFor(_produit(open: null)),
        QuickAddAction.addDirectly,
      );
    });
  });

  group('ProductAvailabilityBadge', () {
    testWidgets('fermée : « Boutique fermée », jamais « Disponible »', (
      tester,
    ) async {
      await _monter(
        tester,
        ProductAvailabilityBadge(product: _produit(open: false)),
      );
      expect(find.text('Boutique fermée'), findsOneWidget);
      expect(find.text('Disponible'), findsNothing);
    });

    testWidgets('ouverte : « Disponible »', (tester) async {
      await _monter(
        tester,
        ProductAvailabilityBadge(product: _produit(open: true)),
      );
      expect(find.text('Disponible'), findsOneWidget);
    });

    testWidgets('épuisé : « Épuisé »', (tester) async {
      await _monter(
        tester,
        ProductAvailabilityBadge(
          product: _produit(open: true, stockRestant: 0),
        ),
      );
      expect(find.text('Épuisé'), findsOneWidget);
    });
  });

  testWidgets('carte vendeur : boutique fermée ⇒ pas de bouton d\'ajout', (
    tester,
  ) async {
    await _monter(tester, VendorProductCard(product: _produit(open: false)));
    expect(find.text('Fermé'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ajouter Poulet braisé au panier'),
      findsNothing,
    );
  });
}
