import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/presentation/widgets/product_stock_widgets.dart';
import 'package:lilia_app/models/produit.dart';

void main() {
  testWidgets('selector affiche conversion, prix et bloque le format épuisé', (
    tester,
  ) async {
    ProductVariant? selected;
    final variants = [
      ProductVariant(
        id: 'case-6',
        label: 'Carton de 6',
        prix: 70000,
        stockConsumption: 6,
        availableQuantity: 2,
        stockStatus: 'LOW',
      ),
      ProductVariant(
        id: 'bottle',
        label: 'Bouteille',
        prix: 12000,
        availableQuantity: 0,
        stockStatus: 'OUT_OF_STOCK',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VariantSelector(
            variants: variants,
            selected: null,
            onSelected: (variant) => selected = variant,
          ),
        ),
      ),
    );

    expect(find.text('Contient 6 unités'), findsOneWidget);
    expect(find.text('Plus que 2 disponibles'), findsOneWidget);
    expect(find.text('Épuisé'), findsOneWidget);

    await tester.tap(find.text('Bouteille'));
    await tester.pump();
    expect(selected, isNull);

    await tester.tap(find.text('Carton de 6'));
    await tester.pump();
    expect(selected?.id, 'case-6');
  });
}
