// « Commander plus tard » — restauration d'une commande en attente.
//
// Constaté le 02/10/2026 : un article qui ne revenait pas dans le panier
// (épuisé, boutique fermée, panier d'un autre vendeur) n'était que journalisé,
// et la commande en attente était supprimée quand même. Les menus, eux,
// revenaient ligne à ligne comme des articles seuls, au prix de chaque plat.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/application/draft_orders_provider.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/draft_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/fake_auth_repository.dart';

class _PanierEspion extends CartController {
  _PanierEspion({this.refuse = const {}});
  final Set<String> refuse;
  final articles = <String>[];
  final menus = <String>[];

  @override
  Future<Cart?> build() async => null;

  @override
  Future<void> addItem({
    required String variantId,
    int quantity = 1,
    CartItemPreview? preview,
    bool awaitServer = false,
  }) async {
    if (refuse.contains(variantId)) {
      throw CartException('Ce produit est épuisé');
    }
    articles.add('$variantId×$quantity');
  }

  @override
  Future<void> addMenu({
    required String menuId,
    int quantity = 1,
    MenuCartPreview? preview,
  }) async {
    menus.add('$menuId×$quantity');
  }
}

CartItem _ligne(String variant, {int prix = 2000, int qte = 1, String? menu}) =>
    CartItem(
      id: 'i-$variant',
      cartId: 'c',
      productId: 'p-$variant',
      variantId: variant,
      quantite: qte,
      createdAt: DateTime(2026, 10, 1),
      product: ProductItem(nom: 'Plat $variant', restaurantId: 'resto-1'),
      variant: VariantItem(label: 'Normal', prix: prix),
      menuId: menu,
      menu: menu == null
          ? null
          : MenuInfo(id: menu, nom: 'Menu midi', prix: 5000),
    );

Future<(ProviderContainer, _PanierEspion)> _monter(
  List<CartItem> items, {
  Set<String> refuse = const {},
}) async {
  final draft = DraftOrder(
    id: 'd-1',
    restaurantName: 'Chez Lilia',
    items: items,
    totalPrice: Cart(
      id: '',
      userId: '',
      items: items,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ).totalPrice,
    createdAt: DateTime(2026, 10, 1),
  );
  SharedPreferences.setMockInitialValues({
    'draft_orders__invite': [draft.toJson()],
  });
  final espion = _PanierEspion(refuse: refuse);
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      cartControllerProvider.overrideWith(() => espion),
    ],
  );
  addTearDown(c.dispose);
  await c.read(draftOrdersProvider.future);
  return (c, espion);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tout revient : la commande en attente disparaît', () async {
    final (c, espion) = await _monter([_ligne('a', qte: 2), _ligne('b')]);
    await c.read(draftOrdersProvider.notifier).restoreDraft('d-1');
    expect(espion.articles, ['a×2', 'b×1']);
    expect(c.read(draftOrdersProvider).value, isEmpty);
  });

  test('un menu revient en tant que menu, une seule fois', () async {
    final (c, espion) = await _monter([
      _ligne('a'),
      _ligne('m1', menu: 'menu-1'),
      _ligne('m2', menu: 'menu-1'),
    ]);
    await c.read(draftOrdersProvider.notifier).restoreDraft('d-1');
    expect(
      espion.articles,
      ['a×1'],
      reason:
          'les plats du menu ne sont pas '
          'rajoutés comme articles seuls',
    );
    expect(espion.menus, ['menu-1×1']);
  });

  test(
    'échec partiel : message clair, rien de perdu, rien de dupliqué',
    () async {
      final (c, espion) = await _monter(
        [_ligne('a', prix: 2000), _ligne('b', prix: 3000, qte: 2)],
        refuse: {'b'},
      );
      await expectLater(
        c.read(draftOrdersProvider.notifier).restoreDraft('d-1'),
        throwsA(
          isA<CartException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Plat b'),
              contains('épuisé'),
              contains('conservée'),
            ),
          ),
        ),
      );
      expect(espion.articles, ['a×1']);
      final reste = c.read(draftOrdersProvider).value!.single;
      expect(reste.items.map((i) => i.variantId), [
        'b',
      ], reason: 'seul ce qui n’est pas revenu reste en attente');
      expect(reste.totalPrice, 6000);
    },
  );
}
