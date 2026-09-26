import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/models/produit.dart';

/// F3-10 — un format porte le verdict de stock du serveur.
void main() {
  test('lit consommation et verdict', () {
    final carton = ProductVariant.fromJson({
      'id': 'c6',
      'label': 'Carton de 6',
      'prix': 70000,
      'stockConsumption': 6,
      'availableQuantity': 0,
      'stockStatus': 'OUT_OF_STOCK',
    });
    expect(carton.stockConsumption, 6);
    expect(carton.isSoldOut, isTrue);
    expect(carton.lowQuantity, isNull);
  });

  test('« Plus que N » seulement quand le serveur dit LOW', () {
    final bouteille = ProductVariant.fromJson({
      'id': 'b',
      'prix': 13000,
      'availableQuantity': 3,
      'stockStatus': 'LOW',
    });
    expect(bouteille.lowQuantity, 3);
    expect(bouteille.isSoldOut, isFalse);
  });

  test('serveur antérieur à F3-10 : consommation 1, aucun verdict', () {
    final v = ProductVariant.fromJson({'id': 'v', 'prix': 1000});
    expect(v.stockConsumption, 1);
    expect(v.availableQuantity, isNull);
    expect(v.isSoldOut, isFalse);
  });
}
