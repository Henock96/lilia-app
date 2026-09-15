import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/models/cart.dart';

/// Le compteur du panier, et la garantie qu'il ne fait pas reconstruire
/// l'application entière.
///
/// Pas de serveur ici : un `testWidgets` tourne sous horloge simulée, où les
/// entrées-sorties réelles ne progressent pas. Le repository est donc remplacé
/// par un double — ce qui est de toute façon le bon niveau, ce test portant sur
/// le ciblage des reconstructions, pas sur le réseau.
class _FauxRepository implements CartRepository {
  /// Panier « serveur ». Les mutations y sont réellement appliquées, comme le
  /// fait `CartItemsService.addItem`, puis le panier complet est renvoyé :
  /// sans cela l'état optimiste serait écrasé par un panier vide au retour, et
  /// le test mesurerait le contraire de ce qu'il croit.
  Cart panierServeur = Cart(
    id: 'cart-1',
    userId: 'user-1',
    items: const [],
    createdAt: DateTime(2026, 9, 8),
    updatedAt: DateTime(2026, 9, 8),
  );

  /// Aperçus vus passer, pour rejouer la mutation côté « serveur ».
  final Map<String, CartItemPreview> apercus = {};

  @override
  Future<Cart?> getCart() async => panierServeur;

  @override
  Future<Cart?> addToCart({
    required String variantId,
    required int quantity,
  }) async {
    final apercu = apercus[variantId];
    if (apercu != null) {
      panierServeur = applyAddItem(panierServeur, apercu, quantity);
    }
    return panierServeur;
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non utilisé ici');
}

void main() {
  late _FauxRepository repo;

  ProviderContainer monter() {
    repo = _FauxRepository();
    final container = ProviderContainer(
      overrides: [
        cartRepositoryProvider.overrideWithValue(repo),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('aucun réseau attendu'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget compteur(void Function() onBuild) => Consumer(
    builder: (_, ref, _) {
      onBuild();
      final total = ref.watch(
        cartControllerProvider.select((cart) => cart.value?.totalItems ?? 0),
      );
      return Text('$total');
    },
  );

  testWidgets('seul le compteur se reconstruit quand le panier change', (
    tester,
  ) async {
    final container = monter();
    var buildsCoque = 0;
    var buildsCompteur = 0;

    // Reproduit la structure de `BottomNavigationPage` : une coque qui ne
    // regarde pas le panier, et un compteur qui n'en regarde que le total.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (_) {
              buildsCoque++;
              return Scaffold(body: compteur(() => buildsCompteur++));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
    final coqueInitial = buildsCoque;
    final compteurInitial = buildsCompteur;

    repo.apercus['var-1'] = _apercu();
    container.read(cartControllerProvider.notifier).addItem(
      variantId: 'var-1',
      preview: _apercu(),
    );
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(
      buildsCompteur,
      greaterThan(compteurInitial),
      reason: 'Le compteur suit le panier.',
    );
    expect(
      buildsCoque,
      coqueInitial,
      reason:
          'La coque de navigation — donc les 4 onglets et tout ce qu\'ils '
          'portent — ne doit pas se reconstruire pour un ajout au panier.',
    );
  });

  testWidgets('un prix qui change ne redessine pas le compteur', (
    tester,
  ) async {
    final container = monter();
    var builds = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: compteur(() => builds++)),
      ),
    );
    await tester.pump();

    repo.apercus['var-1'] = _apercu();
    container.read(cartControllerProvider.notifier).addItem(
      variantId: 'var-1',
      preview: _apercu(),
    );
    await tester.pump();
    final apresAjout = builds;

    // Même total, prix différent : `select` ne voit aucun changement.
    final courant = container.read(cartControllerProvider).value!;
    container.read(cartControllerProvider.notifier).state = AsyncData(
      courant.copyWith(
        items: [
          courant.items.single.copyWith(
            variant: VariantItem(label: 'Normale', prix: 9999),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      builds,
      apresAjout,
      reason: '`select` sur totalItems : un prix qui change ne redessine pas '
          'la barre de navigation.',
    );
  });

  testWidgets('le compteur additionne les quantités, pas les lignes', (
    tester,
  ) async {
    final container = monter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: compteur(() {})),
      ),
    );
    await tester.pump();

    repo.apercus['var-1'] = _apercu();
    repo.apercus['var-2'] = _apercu(variantId: 'var-2');
    final notifier = container.read(cartControllerProvider.notifier);
    notifier.addItem(variantId: 'var-1', quantity: 2, preview: _apercu());
    notifier.addItem(
      variantId: 'var-2',
      quantity: 3,
      preview: _apercu(variantId: 'var-2'),
    );
    await tester.pump();

    expect(find.text('5'), findsOneWidget);
  });
}

CartItemPreview _apercu({String variantId = 'var-1'}) => CartItemPreview(
  productId: 'prod-$variantId',
  variantId: variantId,
  product: ProductItem(nom: 'Poulet', restaurantId: 'resto-1'),
  variant: VariantItem(label: 'Normale', prix: 3500),
);
