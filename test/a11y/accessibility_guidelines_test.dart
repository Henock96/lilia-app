// Garde-fous d'accessibilité automatisés.
//
// L'app ne comptait aucun `Semantics`, aucun `semanticLabel` et 2 tooltips pour
// 31 `IconButton` : tous les boutons d'icône étaient annoncés « bouton », sans
// indication de leur fonction. Ces tests utilisent les quatre guidelines
// fournies par `flutter_test` (aucune dépendance à ajouter) pour empêcher la
// régression sur les écrans montables sans réseau.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/quartiers/application/quartiers_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/theme/app_theme.dart';

const _restaurantId = 'resto-1';

void main() {
  group('Guidelines d\'accessibilité — écran mode de livraison', () {
    testWidgets('cibles tactiles Android et iOS', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('contraste du texte', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
    });

    testWidgets('cibles tactiles étiquetées', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });
  });

  group('Widgets partagés', () {
    testWidgets('AppCachedImage annonce son label quand il est fourni', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCachedImage(
              imageUrl: null,
              width: 100,
              height: 100,
              semanticLabel: 'Photo du plat Poulet braisé',
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Photo du plat Poulet braisé'), findsOne);
      handle.dispose();
    });

    testWidgets('AppCachedImage sans label est masqué aux lecteurs d\'écran', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCachedImage(imageUrl: null, width: 100, height: 100),
          ),
        ),
      );

      // Une image décorative ne doit pas polluer le parcours du lecteur.
      final node = tester.getSemantics(find.byType(AppCachedImage));
      expect(node.label, isEmpty);
      handle.dispose();
    });

    testWidgets('AppCachedAvatar expose son label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCachedAvatar(
              imageUrl: null,
              semanticLabel: 'Photo de profil de Awa',
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Photo de profil de Awa'), findsOne);
      handle.dispose();
    });
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider.overrideWith(() => _FakeCart(_cart())),
        quartiersListProvider.overrideWith((ref) async => _quartiers),
        adresseControllerProvider.overrideWith(() => _FakeAdresses()),
        restaurantControllerProvider(
          _restaurantId,
        ).overrideWith((ref) async => _restaurant()),
      ],
      // Thème réel : c'est lui qui porte les couleurs testées par
      // `textContrastGuideline`.
      child: MaterialApp(
        theme: AppTheme.light,
        home: const DeliveryOptionsPage(),
      ),
    ),
  );
  // Pas de `pumpAndSettle` : certaines animations de l'app tournent en boucle.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _FakeCart extends CartController {
  _FakeCart(this._cart);
  final Cart? _cart;

  @override
  Stream<Cart?> build() => Stream<Cart?>.value(_cart);
}

class _FakeAdresses extends AdresseController {
  @override
  Future<List<Adresse>> build() async => _adresses;
}

Cart _cart() => Cart(
  id: 'cart-1',
  userId: 'user-1',
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
  items: [
    CartItem(
      id: 'item-1',
      cartId: 'cart-1',
      productId: 'prod-1',
      variantId: 'var-1',
      quantite: 2,
      createdAt: DateTime(2026, 8, 1),
      product: ProductItem(nom: 'Poulet braisé', restaurantId: _restaurantId),
      variant: VariantItem(label: 'Normal', prix: 3000),
    ),
  ],
);

Restaurant _restaurant() => Restaurant(
  id: _restaurantId,
  name: 'Chez Maman Lili',
  address: 'Poto-Poto, Brazzaville',
  products: const [],
  categoriesMap: const {},
  vendorType: VendorType.RESTAURANT,
);

final _quartiers = [
  Quartier(id: 'q-1', nom: 'Poto-Poto', ville: 'Brazzaville'),
  Quartier(id: 'q-2', nom: 'Bacongo', ville: 'Brazzaville'),
];

final _adresses = [
  Adresse(
    id: 'adr-1',
    rue: '12 rue de la Paix',
    ville: 'Brazzaville',
    country: 'CG',
    userId: 'user-1',
    quartierId: 'q-1',
  ),
];
