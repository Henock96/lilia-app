@Tags(['perf'])
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';

import 'cart_bench_harness.dart';

/// Banc de mesure « tap → retour visuel » (audit de performance, sept. 2026).
///
/// Il ne mesure pas le réseau : il mesure **le nombre d'allers-retours que
/// l'architecture cliente impose**, et le traduit en millisecondes avec une
/// latence serveur injectée. Le vrai `ApiClient` (Dio + les 4 interceptors) et
/// le vrai `CartRepository` sont traversés ; seul le serveur est local.
///
/// Latence injectée = celle **mesurée sur la production** le 08/09/2026 :
///
/// ```
/// $ curl -w '%{time_starttransfer}' https://lilia-backend.onrender.com/health/live
///   1,12 s / 1,11 s / 1,13 s   (connexion neuve)
///   0,93 s                     (connexion keep-alive réutilisée)
/// ```
///
/// On retient **930 ms**, le cas le plus favorable. Tout chiffre produit ici
/// est donc un plancher optimiste.
void main() {
  late CartBench bench;
  late CartRepository repo;

  tearDown(() => bench.fermer());

  Future<void> monter({int latenceMs = kLatenceServeurMesureeMs}) async {
    bench = await CartBench.demarrer(latenceMs: latenceMs);
    repo = bench.repository;
  }

  test('un ajout au panier ne coûte plus qu\'UN aller-retour', () async {
    await monter();

    final chrono = Stopwatch()..start();
    final cart = await repo.addToCart(variantId: 'var-1', quantity: 1);
    final duree = chrono.elapsedMilliseconds;
    chrono.stop();

    // ignore: avoid_print
    print('''
┌─ P-01 — coût réseau d'un ajout ───────────────────────────────────────
│ Latence serveur injectée .... $kLatenceServeurMesureeMs ms/requête (mesurée en prod)
│ Requêtes HTTP émises ........ ${bench.nombreRequetes}  → ${bench.appels.join(', ')}
│ Durée de l'appel ............ $duree ms
│ AVANT (2 allers-retours) .... ~${2 * kLatenceServeurMesureeMs} ms
└──────────────────────────────────────────────────────────────────────''');

    expect(
      bench.appels,
      ['POST /cart/add'],
      reason:
          'Le GET /cart qui suivait est supprimé : POST /cart/add renvoie déjà '
          'le panier complet (cart-items.service.ts).',
    );
    expect(cart, isNotNull);
    expect(cart!.items.single.quantite, 1);
    expect(
      duree,
      lessThan(2 * kLatenceServeurMesureeMs),
      reason: 'Un seul aller-retour, donc sous le double de la latence.',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('changer une quantité ne coûte plus qu\'UN aller-retour', () async {
    await monter(latenceMs: 30);
    await repo.addToCart(variantId: 'var-1', quantity: 1);
    bench.reset();

    await repo.updateItemQuantity(cartItemId: 'item-var-1', quantity: 4);

    expect(bench.appels, ['PATCH /cart/items/item-var-1']);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('supprimer un article ne coûte plus qu\'UN aller-retour', () async {
    await monter(latenceMs: 30);
    await repo.addToCart(variantId: 'var-1', quantity: 1);
    bench.reset();

    await repo.removeItem(cartItemId: 'item-var-1');

    expect(bench.appels, ['DELETE /cart/items/item-var-1']);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'la recommande, elle, doit bien relire le panier — son contrat diffère',
    () async {
      await monter(latenceMs: 30);

      final result = await repo.reorderFromOrder(orderId: 'order-1');

      expect(
        bench.appels,
        ['POST /orders/order-1/reorder', 'GET /cart'],
        reason:
            'POST /orders/:id/reorder renvoie un rapport de recommande, pas un '
            'panier : la relecture est ici nécessaire, pas redondante.',
      );
      expect(result.report['added'], isNotNull);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('vider le panier n\'attend aucun panier en retour', () async {
    await monter(latenceMs: 30);
    await repo.addToCart(variantId: 'var-1', quantity: 1);
    bench.reset();

    await repo.clearAllItems();

    expect(
      bench.appels,
      ['DELETE /cart/clear'],
      reason:
          'DELETE /cart/clear renvoie { count } — il n\'y a pas de panier à '
          'adopter, l\'état résultant est « vide » par construction.',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
