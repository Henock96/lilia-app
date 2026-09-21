// Test 5 du cahier des charges : **le panier ne se perd jamais à la connexion.**
//
// C'est la garantie la plus coûteuse à violer de tout le mode visiteur : un
// client qui a composé son panier, qui se connecte pour le payer, et qui
// retombe sur un panier vide ne recommence pas — il s'en va.
//
// Le magasin local est réel (`SharedPreferences` en mémoire) et le dépôt est un
// double qui applique vraiment les ajouts : ce qui est vérifié ici est le
// CONTENU final, pas le nombre d'appels.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/data/guest_cart_store.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dépôt de panier **serveur** simulé : il applique réellement les ajouts, pour
/// qu'on puisse observer le panier obtenu plutôt que des appels comptés.
class _FauxDepot implements CartRepository {
  _FauxDepot({Cart? initial}) : _cart = initial;

  Cart? _cart;
  bool videAppele = false;
  Object? erreurAAjout;
  /// Variantes que le serveur refuse — rupture, retrait, fenêtre horaire.
  final Set<String> refusees = {};

  @override
  Future<Cart?> getCart() async => _cart;

  @override
  Future<Cart?> addToCart({
    required String variantId,
    required int quantity,
  }) async {
    if (erreurAAjout != null) throw erreurAAjout!;
    if (refusees.contains(variantId)) {
      throw CartException('Produit épuisé.', code: 'INVALID_DATA');
    }
    _cart = applyAddItem(
      _cart,
      CartItemPreview(
        productId: 'prod-$variantId',
        variantId: variantId,
        product: ProductItem(nom: variantId, restaurantId: 'resto-serveur'),
        variant: VariantItem(label: 'Standard', prix: 1000),
      ),
      quantity,
    );
    return _cart;
  }

  @override
  Future<void> clearAllItems() async {
    videAppele = true;
    _cart = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

/// Une ligne de panier telle qu'elle est stockée localement.
CartItem _ligne({
  required String variantId,
  String restaurantId = 'resto-1',
  int quantite = 1,
  bool madeToOrder = false,
}) => CartItem(
  id: 'optimistic-$variantId',
  cartId: GuestCartStore.localCartId,
  productId: 'prod-$variantId',
  variantId: variantId,
  quantite: quantite,
  createdAt: DateTime(2026, 9, 19),
  product: ProductItem(
    nom: 'Produit $variantId',
    restaurantId: restaurantId,
    madeToOrder: madeToOrder,
  ),
  variant: VariantItem(label: 'Normale', prix: 3500),
);

CartItemPreview _apercu({
  String variantId = 'var-1',
  String restaurantId = 'resto-1',
  bool madeToOrder = false,
}) => CartItemPreview(
  productId: 'prod-$variantId',
  variantId: variantId,
  product: ProductItem(
    nom: 'Produit $variantId',
    restaurantId: restaurantId,
    madeToOrder: madeToOrder,
  ),
  variant: VariantItem(label: 'Normale', prix: 3500),
);

/// Un menu à deux produits, facturé 4 000 F — soit moins que la somme de ses
/// composants, ce qui est tout l'intérêt d'un menu et le piège du calcul.
MenuCartPreview _menuApercu() => MenuCartPreview(
  menuId: 'menu-1',
  menu: MenuInfo(id: 'menu-1', nom: 'Combo midi', prix: 4000),
  lines: [
    _apercu(variantId: 'menu-var-1'),
    _apercu(variantId: 'menu-var-2'),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FauxDepot depot;
  late ProviderContainer container;
  late bool sessionOuverte;

  /// Monte le contrôleur avec un magasin local réel et un dépôt simulé.
  Future<CartController> monter({
    bool session = false,
    Cart? panierServeur,
    Map<String, Object> prefs = const {},
  }) async {
    sessionOuverte = session;
    SharedPreferences.setMockInitialValues(prefs);
    depot = _FauxDepot(initial: panierServeur);
    container = ProviderContainer(
      overrides: [
        cartRepositoryProvider.overrideWithValue(depot),
        // Lu à chaque geste : la session peut s'ouvrir en cours de test, et
        // c'est précisément le scénario.
        cartSessionIsOpenProvider.overrideWithValue(() => sessionOuverte),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(container.listen(cartControllerProvider, (_, _) {}).close);
    await container.read(cartControllerProvider.future);
    return container.read(cartControllerProvider.notifier);
  }

  Cart? etat() => container.read(cartControllerProvider).value;
  Future<GuestCartStore> magasin() =>
      container.read(guestCartStoreProvider.future);

  group('visiteur — le panier vit en local', () {
    test('un ajout est visible, et survit à la fermeture de l’application', () async {
      final panier = await monter();

      await panier.addItem(variantId: 'var-1', preview: _apercu());

      expect(etat()?.items, hasLength(1));
      expect(etat()!.items.first.variantId, 'var-1');

      // Relecture depuis le magasin : c'est ce qu'un redémarrage ferait.
      expect((await magasin()).read()?.items, hasLength(1));
    });

    test('un ajout joué AVANT la lecture du magasin n’écrase rien', () async {
      // `build()` est asynchrone hors session : il lit `SharedPreferences`.
      // Tant qu'il n'a pas rendu, `state.value` vaut `null` — indiscernable
      // d'un panier vide. Un tap dans cette fenêtre fabriquait un panier d'un
      // seul article et le réécrivait par-dessus celui de la veille.

      // Hier soir : un panier composé et laissé là.
      final hier = await monter();
      await hier.addItem(variantId: 'var-hier', preview: _apercu(variantId: 'var-hier'));
      expect((await magasin()).read()?.items, hasLength(1));

      // Ce matin : l'application redémarre. Le magasin mocké survit, comme
      // `SharedPreferences` sur l'appareil.
      sessionOuverte = false;
      depot = _FauxDepot();
      container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(depot),
          cartSessionIsOpenProvider.overrideWithValue(() => sessionOuverte),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(container.listen(cartControllerProvider, (_, _) {}).close);

      // ⚠️ Aucun `await container.read(cartControllerProvider.future)` ici,
      // contrairement à `monter()`. C'est précisément l'attente que le défaut
      // exploitait : un tap avant la fin de la lecture.
      await container.read(cartControllerProvider.notifier).addItem(
            variantId: 'var-matin',
            preview: _apercu(variantId: 'var-matin'),
          );

      expect(
        (await magasin()).read()?.items.map((i) => i.variantId),
        containsAll(<String>['var-hier', 'var-matin']),
        reason: 'le panier de la veille doit survivre au tap du matin',
      );
    });

    test('les quantités s’additionnent sur la même variante', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-1', preview: _apercu(), quantity: 2);
      await panier.addItem(variantId: 'var-1', preview: _apercu());

      expect(etat()!.items.single.quantite, 3);
    });

    test('la règle « un seul vendeur » s’applique aussi hors session', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-1', preview: _apercu());

      expect(
        () => panier.addItem(
          variantId: 'var-9',
          preview: _apercu(variantId: 'var-9', restaurantId: 'resto-2'),
        ),
        throwsA(isA<CartException>()),
      );
    });

    /// Le menu est décomposable localement — une ligne par produit, la
    /// première variante de chacun, exactement comme `CartMenusService`. Un
    /// visiteur peut donc l'ajouter, et l'accueil met précisément les menus en
    /// avant.
    test('un menu décomposable s’ajoute sans compte', () async {
      final panier = await monter();

      await panier.addMenu(
        menuId: 'menu-1',
        preview: _menuApercu(),
      );

      final items = etat()!.items;
      expect(items, hasLength(2)); // une ligne par produit
      expect(items.every((i) => i.menuId == 'menu-1'), isTrue);
      // ⚠️ Le total est le prix du MENU, pas la somme de ses produits.
      expect(etat()!.totalPrice, 4000);
      expect(etat()!.totalItems, 1);
      expect((await magasin()).read()!.items, hasLength(2));
    });

    test('ajouter deux fois le même menu incrémente ses lignes', () async {
      final panier = await monter();
      await panier.addMenu(menuId: 'menu-1', preview: _menuApercu());
      await panier.addMenu(menuId: 'menu-1', preview: _menuApercu());

      expect(etat()!.items, hasLength(2));
      expect(etat()!.items.every((i) => i.quantite == 2), isTrue);
      expect(etat()!.totalPrice, 8000);
    });

    test('retirer un menu retire TOUTES ses lignes', () async {
      final panier = await monter();
      await panier.addMenu(menuId: 'menu-1', preview: _menuApercu());
      await panier.removeMenu(menuId: 'menu-1');

      expect(etat()?.items ?? const [], isEmpty);
      expect((await magasin()).read(), isNull);
    });

    /// Reste le seul geste du catalogue qui exige une session : un menu que le
    /// client ne sait pas décomposer (produit sans variante — le serveur le
    /// refuse aussi).
    test('un menu non décomposable demande la connexion', () async {
      final panier = await monter();

      await expectLater(
        panier.addMenu(menuId: 'menu-1'),
        throwsA(
          isA<CartException>().having(
            (e) => e.code,
            'code',
            'AUTH_REQUIRED',
          ),
        ),
      );
    });

    test('vider le panier efface le magasin', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-1', preview: _apercu());
      await panier.clearCart();

      expect(etat(), isNull);
      expect((await magasin()).read(), isNull);
    });

    test('aucun appel serveur n’est tenté', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-1', preview: _apercu());
      // `_FauxDepot` lève sur toute méthode non prévue ; `getCart` est la seule
      // appelée au montage, et elle rend `null`. Un `addToCart` serait passé
      // par le dépôt et aurait modifié son panier.
      expect(await depot.getCart(), isNull);
    });
  });

  group('connexion — le panier est repris', () {
    /// **Test 5.** Le scénario nominal : panier composé sans compte, connexion,
    /// panier retrouvé.
    test('5 — panier composé en visiteur, retrouvé après connexion', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-1', preview: _apercu(), quantity: 2);
      await panier.addItem(
        variantId: 'var-2',
        preview: _apercu(variantId: 'var-2'),
      );
      expect(etat()!.items, hasLength(2));

      // La session s'ouvre — c'est `AuthController` qui appelle ceci.
      sessionOuverte = true;
      await panier.adoptGuestCart();

      final apres = etat()!;
      expect(apres.items, hasLength(2));
      expect(
        apres.items.firstWhere((i) => i.variantId == 'var-1').quantite,
        2,
      );
      // Le magasin local est vidé — mais seulement après le versement.
      expect((await magasin()).read(), isNull);
    });

    test('paniers compatibles : les lignes s’ajoutent, rien n’est effacé', () async {
      final panier = await monter(
        prefs: {},
      );
      await panier.addItem(variantId: 'var-visiteur', preview: _apercu(variantId: 'var-visiteur'));

      // Le compte avait déjà un panier, du même vendeur.
      depot._cart = Cart(
        id: 'srv',
        userId: 'u1',
        items: [_ligne(variantId: 'var-compte', restaurantId: 'resto-1')],
        createdAt: DateTime(2026, 9, 18),
        updatedAt: DateTime(2026, 9, 18),
      );

      sessionOuverte = true;
      await panier.adoptGuestCart();

      expect(depot.videAppele, isFalse);
      expect(
        etat()!.items.map((i) => i.variantId),
        containsAll(['var-compte', 'var-visiteur']),
      );
    });

    /// Le serveur refuse un panier à deux vendeurs. Il faut donc en choisir un,
    /// et c'est celui que le client est en train de regarder au moment où il se
    /// connecte **pour le commander**.
    test('paniers incompatibles : le panier du visiteur gagne', () async {
      final panier = await monter();
      await panier.addItem(
        variantId: 'var-visiteur',
        preview: _apercu(variantId: 'var-visiteur', restaurantId: 'resto-1'),
      );

      depot._cart = Cart(
        id: 'srv',
        userId: 'u1',
        items: [_ligne(variantId: 'var-ancien', restaurantId: 'resto-AUTRE')],
        createdAt: DateTime(2026, 9, 18),
        updatedAt: DateTime(2026, 9, 18),
      );

      sessionOuverte = true;
      await panier.adoptGuestCart();

      expect(depot.videAppele, isTrue);
      expect(etat()!.items.map((i) => i.variantId), ['var-visiteur']);
    });

    test('sans panier visiteur, le panier du compte est simplement lu', () async {
      final panier = await monter(
        panierServeur: Cart(
          id: 'srv',
          userId: 'u1',
          items: [_ligne(variantId: 'var-compte')],
          createdAt: DateTime(2026, 9, 18),
          updatedAt: DateTime(2026, 9, 18),
        ),
      );

      sessionOuverte = true;
      await panier.adoptGuestCart();

      expect(depot.videAppele, isFalse);
      expect(etat()!.items.map((i) => i.variantId), ['var-compte']);
    });

    /// Le catalogue bouge pendant que le visiteur compose. Abandonner le
    /// versement entier sur le premier refus renverrait quelqu'un qui a cinq
    /// articles valables à un panier vide, pour une rupture sur le sixième.
    test('une ligne refusée n’emporte pas les autres', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-ok', preview: _apercu(variantId: 'var-ok'));
      await panier.addItem(
        variantId: 'var-epuise',
        preview: _apercu(variantId: 'var-epuise'),
      );

      depot.refusees.add('var-epuise');
      sessionOuverte = true;
      await panier.adoptGuestCart();

      // La ligne valable est passée…
      expect(etat()!.items.map((i) => i.variantId), ['var-ok']);
      // …la refusée reste en local, et elle seule.
      expect(
        (await magasin()).read()!.items.map((i) => i.variantId),
        ['var-epuise'],
      );
      // …et elle est NOMMÉE : « ce n'est pas passé » sans dire quoi oblige à
      // comparer deux écrans de mémoire.
      expect(
        container.read(cartSyncFailuresProvider)?.message,
        contains('Produit var-epuise'),
      );
    });

    /// ⚠️ Un réseau coupé remonte par le MÊME type qu'un produit épuisé. Les
    /// confondre marquerait « n'est plus disponible » sur tout ce qui reste à
    /// verser, au moment précis où rien ne part.
    test('une panne réseau ne fait pas passer les articles pour épuisés', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-1', preview: _apercu());
      await panier.addItem(
        variantId: 'var-2',
        preview: _apercu(variantId: 'var-2'),
      );

      depot.erreurAAjout = CartException('coupé', code: 'NO_INTERNET');
      sessionOuverte = true;
      await panier.adoptGuestCart();

      // Le panier local survit ENTIER.
      expect((await magasin()).read()!.items, hasLength(2));
      final message = container.read(cartSyncFailuresProvider)!.message;
      expect(message, contains('conservé'));
      expect(message, isNot(contains('disponible')));
    });

    /// ⚠️ La garantie qui compte le plus : **un échec ne perd rien**. Le
    /// magasin local n'est vidé qu'après un versement réussi.
    test('si le versement échoue, le panier local est CONSERVÉ', () async {
      final panier = await monter();
      await panier.addItem(variantId: 'var-1', preview: _apercu());

      depot.erreurAAjout = CartException('réseau coupé', code: 'NO_INTERNET');
      sessionOuverte = true;
      await panier.adoptGuestCart();

      expect((await magasin()).read()?.items, hasLength(1));
      // Et le client est prévenu, plutôt que de découvrir un panier vide.
      expect(
        container.read(cartSyncFailuresProvider)?.message,
        contains('conservé'),
      );
    });
  });
}
