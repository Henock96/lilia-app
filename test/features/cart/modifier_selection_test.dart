import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/features/cart/domain/modifier_selection.dart';
import 'package:lilia_app/features/cart/presentation/modifier_group_picker.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/modifier.dart';
import 'package:lilia_app/models/produit.dart';

/// F3-09 — sélecteur d'options (ergonomie) et identité des lignes de panier.
///
/// Carte de la fiche : Poulet braisé 3 000 — Accompagnement obligatoire
/// (Alloco +500 / Frites / Riz épuisé) — Suppléments 0 à 2 (Œuf +300 ×3,
/// Fromage +500, Piment).
const accompagnement = ModifierGroup(
  id: 'g-acc',
  name: 'Accompagnement',
  minSelect: 1,
  maxSelect: 1,
  options: [
    ModifierOption(id: 'alloco', name: 'Alloco', priceDeltaXaf: 500),
    ModifierOption(id: 'frites', name: 'Frites'),
    ModifierOption(id: 'riz', name: 'Riz', isAvailable: false),
  ],
);
const supplements = ModifierGroup(
  id: 'g-sup',
  name: 'Suppléments',
  minSelect: 0,
  maxSelect: 2,
  options: [
    ModifierOption(id: 'oeuf', name: 'Œuf', priceDeltaXaf: 300, maxQuantity: 3),
    ModifierOption(id: 'fromage', name: 'Fromage', priceDeltaXaf: 500),
    ModifierOption(id: 'piment', name: 'Piment'),
  ],
);

void main() {
  group('ModifierSelectionState', () {
    late ModifierSelectionState s;
    setUp(() => s = ModifierSelectionState([accompagnement, supplements]));

    test('groupe obligatoire vide : bouton bloqué, et dit lequel', () {
      expect(s.blockingReason, 'Choisissez « Accompagnement »');
      s.toggle(accompagnement, accompagnement.options[0]);
      expect(s.blockingReason, isNull);
    });

    test('choix unique : choisir remplace (radio), et ne se décoche pas s’il est obligatoire', () {
      s.toggle(accompagnement, accompagnement.options[0]);
      s.toggle(accompagnement, accompagnement.options[1]);
      expect(s.isSelected('alloco'), isFalse);
      expect(s.isSelected('frites'), isTrue);
      s.toggle(accompagnement, accompagnement.options[1]);
      expect(s.isSelected('frites'), isTrue);
    });

    test('option épuisée : jamais sélectionnable', () {
      expect(s.toggle(accompagnement, accompagnement.options[2]), isFalse);
      expect(s.isSelected('riz'), isFalse);
    });

    test('maxSelect compte les options distinctes : la 3ᵉ est refusée, pas la quantité', () {
      expect(s.toggle(supplements, supplements.options[0]), isTrue);
      s.setQuantity(supplements.options[0], 3);
      expect(s.toggle(supplements, supplements.options[1]), isTrue);
      expect(s.toggle(supplements, supplements.options[2]), isFalse);
      expect(s.quantityOf('oeuf'), 3);
    });

    test('quantité bornée à maxQuantity', () {
      s.toggle(supplements, supplements.options[0]);
      s.setQuantity(supplements.options[0], 9);
      expect(s.quantityOf('oeuf'), 3);
      s.setQuantity(supplements.options[0], 0);
      expect(s.quantityOf('oeuf'), 1);
    });

    test('lignes dans l’ordre de la carte, et valeur des suppléments', () {
      s.toggle(supplements, supplements.options[0]);
      s.setQuantity(supplements.options[0], 2);
      s.toggle(accompagnement, accompagnement.options[0]);
      expect(s.lines.map((l) => l.label), ['Alloco', 'Œuf ×2']);
      expect(s.optionsValue, 500 + 600);
    });
  });

  group('identité d’une ligne de panier', () {
    CartItemPreview apercu(List<LineOption> options) => CartItemPreview(
      productId: 'p',
      variantId: 'v',
      product: ProductItem(nom: 'Poulet braisé', restaurantId: 'r'),
      variant: VariantItem(label: 'Standard', prix: 3000),
      options: options,
    );
    const a = LineOption(optionId: 'b-opt', groupName: 'g', name: 'B', quantity: 2);
    const b = LineOption(optionId: 'a-opt', groupName: 'g', name: 'A');

    test('la clé locale suit la signature serveur : triée, indépendante de l’ordre', () {
      expect(apercu([a, b]).optionsKey, 'a-opt:1,b-opt:2');
      expect(apercu([b, a]).optionsKey, apercu([a, b]).optionsKey);
      expect(apercu(const []).optionsKey, '');
    });

    test('même sélection → même ligne ; sélection différente → nouvelle ligne', () {
      var cart = applyAddItem(null, apercu([a, b]), 1);
      cart = applyAddItem(cart, apercu([b, a]), 2);
      cart = applyAddItem(cart, apercu([b]), 1);
      cart = applyAddItem(cart, apercu(const []), 1);
      expect(cart.items.map((i) => [i.optionsSignature, i.quantite]), [
        ['a-opt:1,b-opt:2', 3],
        ['a-opt:1', 1],
        ['', 1],
      ]);
      // Identifiants provisoires distincts : aucune collision de ligne.
      expect(cart.items.map((i) => i.id).toSet(), hasLength(3));
    });
  });

  group('modèles', () {
    test('Product lit les groupes et le verdict du serveur', () {
      final p = Product.fromJson({
        'id': 'p',
        'nom': 'Poulet braisé',
        'prixOriginal': 3000,
        'restaurantId': 'r',
        'variants': [
          {'id': 'v', 'prix': 3000},
        ],
        'modifierGroups': [
          {
            'id': 'g',
            'name': 'Accompagnement',
            'minSelect': 1,
            'maxSelect': 1,
            'required': true,
            'options': [
              {'id': 'o', 'name': 'Alloco', 'priceDeltaXaf': 500, 'maxQuantity': 1, 'isAvailable': false},
            ],
          },
        ],
        'modifiersUnavailableReason': 'plus aucun choix',
      });
      expect(p.hasModifiers, isTrue);
      expect(p.modifierGroups.single.options.single.isAvailable, isFalse);
      expect(p.isOrderable, isFalse);
      expect(p.unavailability, ProductUnavailability.optionsIndisponibles);
    });

    test('Product d’une réponse antérieure : aucun groupe, commandable', () {
      final p = Product.fromJson({
        'id': 'p',
        'nom': 'Plat',
        'prixOriginal': 1000,
        'restaurantId': 'r',
      });
      expect(p.hasModifiers, isFalse);
      expect(p.isOrderable, isTrue);
    });

    test('CartItem lit les totaux du serveur — le prix unitaire serveur fait foi', () {
      final item = CartItem.fromMap({
        'id': 'l',
        'cartId': 'c',
        'productId': 'p',
        'variantId': 'v',
        'quantite': 2,
        'product': {'nom': 'Poulet', 'restaurantId': 'r'},
        'variant': {'label': 'Standard', 'prix': 3000},
        'optionsSignature': 'alloco:1',
        'options': [
          {'optionId': 'alloco', 'groupName': 'Accompagnement', 'name': 'Alloco', 'priceDeltaXaf': 500, 'quantity': 1},
        ],
        // Le serveur a relu un prix plus récent que le catalogue en cache.
        'unitPriceXaf': 3600,
        'optionsTotalXaf': 600,
        'lineTotalXaf': 7200,
        'issue': {'code': 'MODIFIER_UNAVAILABLE', 'message': 'Alloco n’est plus disponible'},
      });
      expect(item.unitPrice, 3600);
      expect(item.options.single.name, 'Alloco');
      expect(item.issue?.code, 'MODIFIER_UNAVAILABLE');
      final cart = Cart(
        id: 'c',
        userId: 'u',
        items: [item],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(cart.totalPrice, 7200);
      expect(cart.hasIssues, isTrue);
    });

    test('OrderItem : options figées lues depuis la commande', () {
      final opt = LineOption.fromJson({
        'optionId': null,
        'groupName': 'Suppléments',
        'optionName': 'Œuf',
        'priceDeltaXaf': 300,
        'quantity': 2,
      });
      expect(opt.name, 'Œuf');
      expect(opt.label, 'Œuf ×2');
    });
  });

  group('ModifierGroupPicker', () {
    testWidgets('radio, épuisé grisé, quantités et prix', (tester) async {
      final state = ModifierSelectionState([accompagnement, supplements]);
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => ModifierGroupPicker(
                  state: state,
                  onChanged: () => setState(() => changes++),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Obligatoire'), findsOneWidget);
      expect(find.text('Facultatif · 2 au maximum'), findsOneWidget);
      expect(find.text('Épuisé'), findsOneWidget);
      expect(find.text('+500'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('modifier-option-riz')));
      await tester.pump();
      expect(state.isSelected('riz'), isFalse);
      expect(changes, 0);

      await tester.tap(find.byKey(const ValueKey('modifier-option-alloco')));
      await tester.tap(find.byKey(const ValueKey('modifier-option-oeuf')));
      await tester.pump();
      expect(state.isSelected('alloco'), isTrue);
      // Pas-à-pas visible pour une option à quantité multiple.
      await tester.tap(find.byTooltip('Plus'));
      await tester.pump();
      expect(state.quantityOf('oeuf'), 2);
      expect(state.blockingReason, isNull);
      expect(state.optionsValue, 500 + 600);
    });
  });
}
