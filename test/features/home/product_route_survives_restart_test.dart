// **Une route ne doit pas dépendre d'un objet en mémoire.**
//
// La fiche produit ne se rendait que depuis un `Product` passé en `extra` de
// navigation. `extra` n'est pas sérialisable : go_router restaure
// l'emplacement après une mort de processus — mémoire basse, « Ne pas
// conserver les activités », retour d'un appel téléphonique — mais **jamais**
// la charge utile. Le client retrouvait `NotFoundScreen` à la place de sa
// fiche.
//
// Reproduire une mort de processus dans un test de widget est impossible. Ce
// qu'on reproduit, c'est son effet observable, et c'est le même : la page est
// construite avec l'identifiant du chemin et **sans** `extra`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/presentation/product_detail_page.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

Product _produit() => Product(
      id: 'prod-1',
      name: 'Poulet braisé',
      description: 'Avec du piment',
      prixOriginal: 5000,
      restaurantId: 'resto-1',
      variants: const [],
    );

void main() {
  test('la route porte l’identifiant dans son CHEMIN', () {
    expect(
      AppRoutes.productDetail.path,
      contains(':productId'),
      reason:
          'sans paramètre de chemin, l’emplacement restauré ne désigne aucun '
          'produit et la page ne peut que rendre « introuvable »',
    );
  });

  Future<void> monter(
    WidgetTester tester, {
    Product? extra,
    required Future<Product> Function() chargement,
  }) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productByIdProvider('prod-1').overrideWith((ref) => chargement()),
        ],
        child: MaterialApp(
          home: ProductDetailPage(productId: 'prod-1', product: extra),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
    }
  }

  testWidgets('SANS extra — après restauration — la fiche se charge', (
    tester,
  ) async {
    var appels = 0;
    await monter(
      tester,
      chargement: () async {
        appels++;
        return _produit();
      },
    );

    expect(appels, 1, reason: 'la page doit aller chercher ce qu’elle n’a pas');
    expect(find.text('Poulet braisé'), findsWidgets);
    expect(find.textContaining('introuvable'), findsNothing);
  });

  testWidgets('AVEC extra — chemin rapide — aucun aller-retour', (
    tester,
  ) async {
    var appels = 0;
    await monter(
      tester,
      extra: _produit(),
      chargement: () async {
        appels++;
        return _produit();
      },
    );

    expect(
      appels,
      0,
      reason:
          'arriver d’une liste qui porte déjà le produit ne doit rien coûter '
          'de plus — c’est tout l’intérêt de garder `extra`',
    );
    expect(find.text('Poulet braisé'), findsWidgets);
  });

  testWidgets('produit introuvable : un message et un Réessayer', (
    tester,
  ) async {
    await monter(tester, chargement: () async => throw Exception('404'));

    expect(find.textContaining('Réessayer'), findsWidgets);
  });
}
