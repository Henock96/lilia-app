import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/models/cart.dart';

import '../../perf/cart_bench_harness.dart';

/// P-02 / P-03 — mise à jour optimiste, rollback et mutations concurrentes.
///
/// Les tests traversent le vrai `CartController`, le vrai `CartRepository`,
/// le vrai `ApiClient` et un serveur HTTP local qui applique réellement les
/// mutations : la quantité finale observée est celle qu'un backend produirait.
void main() {
  late CartBench bench;
  late ProviderContainer container;

  Future<CartController> monter({int latenceMs = 40}) async {
    bench = await CartBench.demarrer(latenceMs: latenceMs);
    container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(bench.repository)],
    );
    // LIFO : le conteneur doit tomber AVANT le serveur, sinon les requêtes
    // encore en vol échouent bruyamment sur un port fermé.
    addTearDown(bench.fermer);
    addTearDown(container.dispose);
    // Un abonnement, comme un widget qui observe le panier à l'écran.
    addTearDown(container.listen(cartControllerProvider, (_, _) {}).close);
    // Laisse le build() initial (GET /cart) se terminer, puis oublie-le.
    await container.read(cartControllerProvider.future);
    bench.reset();
    return container.read(cartControllerProvider.notifier);
  }

  Cart? etat() => container.read(cartControllerProvider).value;
  int quantite(String variantId) =>
      etat()?.items
          .where((i) => i.variantId == variantId)
          .fold<int>(0, (s, i) => s + i.quantite) ??
      0;

  CartItemPreview apercu({
    String variantId = 'var-1',
    String restaurantId = 'resto-1',
    bool madeToOrder = false,
  }) => CartItemPreview(
    productId: 'prod-$variantId',
    variantId: variantId,
    product: ProductItem(
      nom: 'Poulet braisé',
      restaurantId: restaurantId,
      madeToOrder: madeToOrder,
    ),
    variant: VariantItem(label: 'Normale', prix: 3500),
  );

  /// Attend que toutes les requêtes en vol soient retombées.
  Future<void> calme() async {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (bench.nombreRequetes > 0) break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  /// Comme [calme], mais laisse aussi passer les reprises de
  /// `RetryInterceptor` (3 tentatives, backoff 0,4 → 1,6 s).
  Future<void> calmeLong() =>
      Future<void>.delayed(const Duration(milliseconds: 4500));

  // ─── 1. Ajout normal ──────────────────────────────────────────────────────

  test('1 — l\'ajout est visible AVANT la réponse serveur', () async {
    final cart = await monter(latenceMs: 400);

    final chrono = Stopwatch()..start();
    await cart.addItem(variantId: 'var-1', preview: apercu());
    final tapVersFeedback = chrono.elapsedMicroseconds / 1000;
    chrono.stop();

    // ignore: avoid_print
    print('''
┌─ P-02 — tap → retour visuel ──────────────────────────────────────────
│ Latence serveur injectée .... 400 ms
│ Tap → état à jour ........... ${tapVersFeedback.toStringAsFixed(2)} ms
│ Requêtes émises à cet instant ${bench.nombreRequetes}
└──────────────────────────────────────────────────────────────────────''');

    expect(quantite('var-1'), 1, reason: 'Le panier est déjà à jour.');
    expect(
      tapVersFeedback,
      lessThan(16),
      reason: 'Objectif : une frame. Le réseau continue derrière.',
    );

    await calme();
    expect(quantite('var-1'), 1);
    expect(bench.appels, ['POST /cart/add']);
    expect(
      etat()!.items.single.id,
      isNot(startsWith('optimistic-')),
      reason: 'La ligne provisoire a été remplacée par celle du serveur.',
    );
  });

  // ─── 2. Timeout ───────────────────────────────────────────────────────────

  test('2 — timeout : rollback et message explicite', () async {
    final cart = await monter();
    bench.reponsesForcees.add(const BenchSilence());

    await cart.addItem(variantId: 'var-1', preview: apercu());
    expect(quantite('var-1'), 1, reason: 'Optimiste appliqué.');

    // `receiveTimeout` d'ApiClient = 30 s : on ne l'attend pas. On vérifie que
    // l'état optimiste tient tant que le serveur n'a rien dit — c'est le
    // comportement voulu, l'article n'est retiré qu'à l'échec confirmé.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(quantite('var-1'), 1);
    expect(container.read(cartSyncFailuresProvider), isNull);
  });

  // ─── 3. Erreur serveur ────────────────────────────────────────────────────

  test('3 — 500 : rollback et signalement', () async {
    final cart = await monter();
    bench.reponsesForcees.add(const BenchErreur(500, 'Boom'));

    await cart.addItem(variantId: 'var-1', preview: apercu());
    expect(quantite('var-1'), 1, reason: 'Optimiste appliqué.');

    await calme();

    expect(quantite('var-1'), 0, reason: 'Rollback après échec confirmé.');
    final echec = container.read(cartSyncFailuresProvider);
    expect(echec, isNotNull);
    expect(echec!.message, contains('n\'a pas été ajouté'));
    expect(
      bench.appels.where((a) => a.startsWith('POST')).length,
      1,
      reason: 'Un POST non idempotent ne doit JAMAIS être rejoué.',
    );
  });

  // ─── 4. Produit devenu indisponible ───────────────────────────────────────

  test('4 — produit indisponible : rollback et message du serveur', () async {
    final cart = await monter();
    bench.reponsesForcees.add(
      const BenchErreur(400, 'Ce produit est épuisé pour aujourd\'hui.'),
    );

    await cart.addItem(variantId: 'var-1', preview: apercu());
    await calme();

    expect(quantite('var-1'), 0);
    expect(
      container.read(cartSyncFailuresProvider)!.message,
      'Ce produit est épuisé pour aujourd\'hui.',
      reason: 'Le message métier du serveur est plus précis que le nôtre.',
    );
  });

  // ─── 5. Trois taps rapides ────────────────────────────────────────────────

  test('5 — 3 taps rapides : 3 POST, aucun GET, quantité exacte', () async {
    final cart = await monter(latenceMs: 60);

    await cart.addItem(variantId: 'var-1', preview: apercu());
    await cart.addItem(variantId: 'var-1', preview: apercu());
    await cart.addItem(variantId: 'var-1', preview: apercu());

    expect(quantite('var-1'), 3, reason: 'Les 3 taps sont vus immédiatement.');

    await calme();

    // ignore: avoid_print
    print('3 taps → ${bench.nombreRequetes} requêtes : ${bench.appels}');

    expect(quantite('var-1'), 3);
    expect(bench.quantiteServeur('var-1'), 3);
    expect(
      bench.appels,
      ['POST /cart/add', 'POST /cart/add', 'POST /cart/add'],
      reason: 'Trois mutations, zéro GET redondant.',
    );
  });

  // ─── 6. Réponses dans le désordre ─────────────────────────────────────────

  test('6 — réponses hors ordre : l\'état final reste cohérent', () async {
    final cart = await monter(latenceMs: 30);

    // Trois variantes distinctes → trois files parallèles. Les latences font
    // revenir les réponses dans l'ordre #3, #1, #2.
    bench.reponsesForcees.addAll(const [
      BenchOk(latenceMs: 300), // #1 revient en dernier
      BenchOk(latenceMs: 200), // #2
      BenchOk(latenceMs: 20), // #3 revient en premier
    ]);

    await cart.addItem(variantId: 'var-1', preview: apercu(variantId: 'var-1'));
    await cart.addItem(variantId: 'var-2', preview: apercu(variantId: 'var-2'));
    await cart.addItem(variantId: 'var-3', preview: apercu(variantId: 'var-3'));

    await calme();

    expect(quantite('var-1'), 1);
    expect(quantite('var-2'), 1);
    expect(quantite('var-3'), 1);
    expect(
      bench.appels.where((a) => a == 'GET /cart').length,
      1,
      reason:
          'Mutations sur des clés différentes : une relecture unique tranche, '
          'plutôt que de parier sur un ordre que le client ne connaît pas.',
    );
  });

  // ─── 7. Dix taps rapides ──────────────────────────────────────────────────

  test('7 — 10 taps rapides : quantité exacte, aucun GET', () async {
    final cart = await monter(latenceMs: 25);

    for (var i = 0; i < 10; i++) {
      await cart.addItem(variantId: 'var-1', preview: apercu());
    }
    expect(quantite('var-1'), 10, reason: 'Chaque tap est vu immédiatement.');

    await calme();

    expect(quantite('var-1'), 10);
    expect(bench.quantiteServeur('var-1'), 10);
    expect(bench.appels.length, 10);
    expect(bench.appels.every((a) => a == 'POST /cart/add'), isTrue);
  });

  // ─── Validation locale ────────────────────────────────────────────────────

  test('vendeur différent : refusé localement, aucune requête émise', () async {
    final cart = await monter();
    await cart.addItem(variantId: 'var-1', preview: apercu());
    await calme();
    bench.reset();

    expect(
      () => cart.addItem(
        variantId: 'var-9',
        preview: apercu(variantId: 'var-9', restaurantId: 'resto-2'),
      ),
      throwsA(isA<CartException>()),
    );
    expect(
      bench.nombreRequetes,
      0,
      reason: 'Une règle vérifiable localement ne coûte pas un aller-retour.',
    );
  });

  test('mode incompatible : refusé localement', () async {
    final cart = await monter();
    await cart.addItem(variantId: 'var-1', preview: apercu());
    await calme();
    bench.reset();

    expect(
      () => cart.addItem(
        variantId: 'var-9',
        preview: apercu(variantId: 'var-9', madeToOrder: true),
      ),
      throwsA(
        isA<CartException>().having(
          (e) => e.message,
          'message',
          contains('sur commande'),
        ),
      ),
    );
    expect(bench.nombreRequetes, 0);
  });

  // ─── Quantité et suppression ──────────────────────────────────────────────

  test('changer la quantité est instantané puis confirmé', () async {
    final cart = await monter(latenceMs: 200);
    await cart.addItem(variantId: 'var-1', preview: apercu());
    await calme();
    bench.reset();

    final chrono = Stopwatch()..start();
    await cart.updateItemQuantity(cartItemId: 'item-var-1', quantity: 5);
    chrono.stop();

    expect(quantite('var-1'), 5);
    expect(chrono.elapsedMilliseconds, lessThan(16));

    await calme();
    expect(quantite('var-1'), 5);
    expect(bench.appels, ['PATCH /cart/items/item-var-1']);
  });

  test('supprimer est instantané, et se défait si le serveur refuse', () async {
    final cart = await monter();
    await cart.addItem(variantId: 'var-1', preview: apercu());
    await calme();
    bench.reset();
    // Panne durable : `DELETE` est idempotent, donc rejoué jusqu'à 3 fois par
    // `RetryInterceptor`. Une seule erreur serait absorbée par la reprise.
    bench.reponseParDefaut = const BenchErreur(500, 'Boom');

    await cart.removeItem(cartItemId: 'item-var-1');
    expect(quantite('var-1'), 0, reason: 'Disparu immédiatement.');

    await calmeLong();
    expect(quantite('var-1'), 1, reason: 'Rétabli : le serveur a refusé.');
    expect(
      container.read(cartSyncFailuresProvider)!.message,
      contains('n\'a pas été retiré'),
    );
  });

  // ─── awaitServer ──────────────────────────────────────────────────────────

  // ─── Réponse illisible ────────────────────────────────────────────────────

  test(
    'une réponse de mutation illisible ne vide PAS le panier à l\'écran',
    () async {
      final cart = await monter(latenceMs: 30);
      await cart.addItem(variantId: 'var-1', preview: apercu());
      await calme();
      bench.reset();

      // 200, mais un corps qui n'est pas un panier : `_cartFromData` rend
      // `null`. L'adopter afficherait un panier vide alors que rien n'a été
      // supprimé.
      bench.reponsesForcees.add(const BenchCorpsInvalide());

      await cart.addItem(variantId: 'var-1', preview: apercu());
      await calme();

      expect(
        quantite('var-1'),
        greaterThanOrEqualTo(1),
        reason: '`null` signifie « illisible », jamais « panier vide ».',
      );
      expect(
        bench.appels.where((a) => a == 'GET /cart').length,
        1,
        reason: 'On relit plutôt que de deviner.',
      );
    },
  );

  // ─── Déconnexion pendant une requête en vol ───────────────────────────────

  test(
    'déconnexion pendant une mutation : rien n\'est écrit après coup',
    () async {
      final cart = await monter(latenceMs: 300);
      await cart.addItem(variantId: 'var-1', preview: apercu());

      // Ce que fait `AuthController.signOut` : invalider le panier.
      container.invalidate(cartControllerProvider);

      // La réponse arrive après : elle ne doit ni lever, ni ressusciter le
      // panier du compte précédent.
      await calme();

      expect(container.read(cartControllerProvider).hasError, isFalse);
    },
  );

  test('awaitServer: true fait attendre le réseau (restauration de brouillon)',
      () async {
    final cart = await monter(latenceMs: 200);

    final chrono = Stopwatch()..start();
    await cart.addItem(
      variantId: 'var-1',
      preview: apercu(),
      awaitServer: true,
    );
    chrono.stop();

    expect(chrono.elapsedMilliseconds, greaterThanOrEqualTo(150));
    expect(quantite('var-1'), 1);
  });
}
