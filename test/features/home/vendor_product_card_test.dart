// Carte produit de la fiche vendeur, extraite de `restaurant_detail_screen`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/features/home/presentation/widgets/vendor_product_card.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/theme/app_theme.dart';

Product _produit({
  List<ProductVariant>? variants,
  int? stockRestant,
  String? imageUrl = 'https://cdn.test/poulet.jpg',
}) => Product(
  id: 'p1',
  name: 'Poulet braisé',
  description: 'Mariné au gingembre',
  prixOriginal: 6000,
  imageUrl: imageUrl,
  restaurantId: 'resto-1',
  categoryId: null,
  isAvailable: true,
  stockRestant: stockRestant,
  variants: variants ?? [ProductVariant(id: 'v1', label: 'Entier', prix: 6000)],
);

Future<void> _monter(WidgetTester tester, Product p, {ThemeData? theme}) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(
            body: ListView(children: [VendorProductCard(product: p)]),
          ),
        ),
      ),
    );

void main() {
  testWidgets('image par le cache disque, pas NetworkImage', (tester) async {
    await _monter(tester, _produit());
    expect(find.byType(AppCachedImage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).image?.image is NetworkImage,
      ),
      findsNothing,
    );
  });

  testWidgets('plusieurs formats : pastille et prix d\'appel', (tester) async {
    await _monter(
      tester,
      _produit(
        variants: [
          ProductVariant(id: 'v1', label: 'Demi', prix: 6000),
          ProductVariant(id: 'v2', label: 'Entier', prix: 12000),
        ],
      ),
    );
    expect(find.text('2 formats'), findsOneWidget);
    expect(find.textContaining('À partir de'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Choisir un format pour Poulet braisé'),
      findsOneWidget,
    );
  });

  testWidgets('épuisé : pastille nommée, pas de bouton d\'ajout, annoncé', (
    tester,
  ) async {
    await _monter(tester, _produit(stockRestant: 0));
    expect(find.textContaining('Ajouter'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'Poulet braisé, .+')), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Ajouter Poulet braisé au panier',
      ),
      findsNothing,
    );
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('contraste et cibles — ${theme.brightness.name}', (
      tester,
    ) async {
      await _monter(tester, _produit(imageUrl: null), theme: theme);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  }
}
