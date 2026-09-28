// L'ajout rapide d'une carte produit ne choisit JAMAIS un format à la place du
// client. Un format unique s'ajoute d'un tap ; plusieurs formats ouvrent une
// feuille où l'épuisé n'est pas sélectionnable ; un format unique épuisé
// n'affiche pas un succès que le serveur défera.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/theme/app_theme.dart';

/// Panier vide qui consigne les ajouts, sans réseau.
class _PanierEspion extends CartController {
  final List<String> ajouts = [];

  @override
  Future<Cart?> build() async => null;

  @override
  bool wouldConflictWithCart(bool newMadeToOrder) => false;

  @override
  Future<void> addItem({
    required String variantId,
    int quantity = 1,
    CartItemPreview? preview,
    bool awaitServer = false,
  }) async {
    ajouts.add(variantId);
  }
}

ProductVariant _format(
  String id, {
  double prix = 1500,
  String? stockStatus,
  int? availableQuantity,
}) => ProductVariant(
  id: id,
  label: id,
  prix: prix,
  stockStatus: stockStatus,
  availableQuantity: availableQuantity,
);

Product _produit(List<ProductVariant> variants) => Product(
  id: 'poulet',
  name: 'Poulet braisé',
  description: '',
  prixOriginal: 6000,
  imageUrl: null,
  restaurantId: 'resto-1',
  categoryId: null,
  isAvailable: true,
  variants: variants,
);

void main() {
  group('quickAddActionFor — la règle', () {
    test('un format vendable : ajout direct', () {
      expect(
        quickAddActionFor(_produit([_format('entier')])),
        QuickAddAction.addDirectly,
      );
    });

    test('plusieurs formats : le client choisit, même si un seul reste', () {
      expect(
        quickAddActionFor(
          _produit([
            _format('demi', stockStatus: 'OUT_OF_STOCK', availableQuantity: 0),
            _format('entier'),
          ]),
        ),
        QuickAddAction.chooseVariant,
      );
    });

    test('format unique épuisé selon le serveur : indisponible', () {
      expect(
        quickAddActionFor(
          _produit([
            _format(
              'entier',
              stockStatus: 'OUT_OF_STOCK',
              availableQuantity: 0,
            ),
          ]),
        ),
        QuickAddAction.unavailable,
      );
    });

    test('LOW et UNLIMITED restent ajoutables', () {
      for (final status in ['LOW', 'UNLIMITED', 'AVAILABLE']) {
        expect(
          quickAddActionFor(_produit([_format('entier', stockStatus: status)])),
          QuickAddAction.addDirectly,
          reason: status,
        );
      }
    });

    test('verdict absent (recherche, populaires) : le serveur arbitre', () {
      expect(
        quickAddActionFor(_produit([_format('entier')])),
        QuickAddAction.addDirectly,
      );
    });
  });

  group('QuickAddButton — le geste', () {
    late _PanierEspion panier;

    Future<void> monter(
      WidgetTester tester,
      Product produit, {
      ThemeData? theme,
    }) async {
      panier = _PanierEspion();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartControllerProvider.overrideWith(() => panier)],
          child: MaterialApp(
            theme: theme ?? AppTheme.light,
            home: Scaffold(
              body: Center(child: QuickAddButton(product: produit)),
            ),
          ),
        ),
      );
    }

    testWidgets('format unique : ajouté sans question', (tester) async {
      await monter(tester, _produit([_format('entier')]));
      expect(
        find.bySemanticsLabel('Ajouter Poulet braisé au panier'),
        findsOneWidget,
      );

      await tester.tap(find.byType(QuickAddButton));
      await tester.pump();

      expect(panier.ajouts, ['entier']);
    });

    testWidgets(
      'plusieurs formats : rien n\'est ajouté avant le choix, l\'épuisé est '
      'refusé, le format choisi est celui ajouté',
      (tester) async {
        await monter(
          tester,
          _produit([
            _format('Demi poulet', prix: 6000),
            _format('Poulet entier', prix: 12000),
            _format(
              'Quart',
              prix: 3500,
              stockStatus: 'OUT_OF_STOCK',
              availableQuantity: 0,
            ),
          ]),
        );
        expect(
          find.bySemanticsLabel('Choisir un format pour Poulet braisé'),
          findsOneWidget,
        );

        await tester.tap(find.byType(QuickAddButton));
        await tester.pumpAndSettle();

        expect(panier.ajouts, isEmpty, reason: 'aucun format implicite');
        expect(find.text('Choisissez un format'), findsOneWidget);
        expect(find.text('Épuisé'), findsOneWidget);

        await tester.tap(find.text('Quart'));
        await tester.pumpAndSettle();
        expect(panier.ajouts, isEmpty);

        await tester.tap(find.text('Poulet entier'));
        await tester.pumpAndSettle();
        expect(panier.ajouts, ['Poulet entier']);
      },
    );

    testWidgets('fermer la feuille n\'ajoute rien', (tester) async {
      await monter(tester, _produit([_format('Demi'), _format('Entier')]));
      await tester.tap(find.byType(QuickAddButton));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // hors de la feuille
      await tester.pumpAndSettle();

      expect(find.text('Choisissez un format'), findsNothing);
      expect(panier.ajouts, isEmpty);
    });

    testWidgets('format unique épuisé : aucun ajout, message clair', (
      tester,
    ) async {
      await monter(
        tester,
        _produit([
          _format('entier', stockStatus: 'OUT_OF_STOCK', availableQuantity: 0),
        ]),
      );

      await tester.tap(find.byType(QuickAddButton));
      await tester.pump();

      expect(panier.ajouts, isEmpty);
      expect(
        find.text('Poulet braisé est épuisé pour le moment.'),
        findsOneWidget,
      );
    });

    testWidgets('zone de tap ≥ 48 px, icône lisible en sombre', (tester) async {
      await monter(tester, _produit([_format('entier')]));
      expect(tester.getSize(find.byType(QuickAddButton)).width, 48);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      // En sombre, `primary` est un orange clair : le blanc y tombait à
      // 2.84:1. L'icône suit `onPrimary`, jamais `Colors.white`.
      await monter(tester, _produit([_format('entier')]), theme: AppTheme.dark);
      await tester.pumpAndSettle(); // AnimatedTheme interpole clair → sombre
      final icone = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icone.color, AppTheme.dark.colorScheme.onPrimary);
      expect(icone.color, isNot(Colors.white));
    });
  });
}
