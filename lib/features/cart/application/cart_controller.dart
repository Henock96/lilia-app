import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/services/analytics_service.dart';

part 'cart_controller.g.dart';

@riverpod
CartRepository cartRepository(Ref ref) =>
    CartRepository(ref.watch(apiClientProvider));

/// Échec de synchronisation survenu **après** que le client a vu son panier
/// changer. Le geste a été accepté à l'écran puis défait : il faut le dire.
///
/// `id` distingue deux échecs successifs porteurs du même texte — sans lui,
/// le second ne déclencherait aucune notification.
class CartSyncFailure {
  final String message;
  final int id;
  const CartSyncFailure(this.message, this.id);
}

/// Canal des échecs de synchronisation du panier.
///
/// Il existe parce que les mutations rendent la main **avant** le réseau : un
/// échec ne peut donc plus être levé vers l'appelant, qui a déjà affiché sa
/// confirmation et n'écoute plus. Un unique `ref.listen` dans la coque de
/// navigation le transforme en message — voir `BottomNavigationPage`.
@Riverpod(keepAlive: true)
class CartSyncFailures extends _$CartSyncFailures {
  int _compteur = 0;

  @override
  CartSyncFailure? build() => null;

  void report(String message) =>
      state = CartSyncFailure(message, ++_compteur);
}

/// État du panier, mises à jour optimistes et réconciliation avec le serveur.
///
/// ## Pourquoi un `AsyncNotifier` et non plus un `Stream`
///
/// Le contrôleur observait auparavant un `StreamController` détenu par le
/// repository : il n'était propriétaire de rien, et il n'existait donc **aucun
/// endroit** où prendre un instantané avant mutation, appliquer un changement
/// local puis le défaire. C'est ce vide qui rendait le retour visuel
/// dépendant du réseau.
///
/// Le type exposé aux widgets est inchangé — `AsyncValue<Cart?>` — donc
/// `ref.watch(cartControllerProvider)`, `.value`, `.when(...)` et
/// `ref.invalidate(...)` se comportent exactement comme avant.
///
/// ## Le contrat des mutations optimistes
///
/// `addItem`, `updateItemQuantity` et `removeItem` **rendent la main dès que
/// l'état local est à jour** (moins d'une milliseconde). Le réseau se poursuit
/// en arrière-plan. Conséquences, à connaître avant d'appeler :
///
/// - une erreur de **validation locale** est levée à l'appelant, de façon
///   synchrone — il peut la présenter comme avant ;
/// - un échec **réseau** ne peut plus l'être : il défait le changement et part
///   dans [cartSyncFailuresProvider].
///
/// Passer `awaitServer: true` rétablit l'attente complète, pour les appelants
/// qui enchaînent des opérations et ont besoin de l'ordre (restauration d'un
/// brouillon).
///
/// Les **menus** n'ont pas de version optimiste : un menu est un groupe de
/// lignes dont la composition n'est connue que du serveur. Les fabriquer
/// localement inventerait un contenu. Ils bénéficient malgré tout de P-01 et
/// ne coûtent plus qu'un aller-retour.
///
/// ## Pourquoi `keepAlive`
///
/// Le provider était en `autoDispose`, contre la convention du projet qui
/// range le panier avec l'authentification et les notifications. C'était sans
/// conséquence visible tant que l'état venait du serveur à chaque lecture ;
/// ça ne l'est plus. L'ajout se fait depuis l'écran vendeur, où **aucun
/// widget n'observe le panier** : le provider y serait détruit aussitôt après
/// la mutation, emportant l'état optimiste et la requête en vol avec lui.
///
/// La destruction reste explicite et voulue — `ref.invalidate(
/// cartControllerProvider)` à la déconnexion et au changement de compte
/// (`auth_controller`), inchangé.
@Riverpod(keepAlive: true)
class CartController extends _$CartController {
  /// Numéro attribué à chaque mutation, dans l'ordre des gestes du client.
  int _sequence = 0;

  /// Mutations dont la réponse n'est pas encore revenue.
  int _enVol = 0;

  /// Clés (variante, ligne, menu) actuellement mutées. Deux clés simultanées
  /// signifient que les réponses peuvent décrire des paniers incomparables.
  final Set<String> _clesEnVol = {};

  /// Vrai dès que deux clés ont été mutées en même temps, ou qu'un échec est
  /// survenu alors que d'autres mutations étaient en vol. Voir [_reconcilier].
  bool _reconciliationRequise = false;

  /// File d'attente par clé : deux gestes sur la **même** variante ne partent
  /// jamais en parallèle.
  final Map<String, Future<void>> _files = {};

  @override
  Future<Cart?> build() => ref.watch(cartRepositoryProvider).getCart();

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  // ─── Mutations sur les articles ────────────────────────────────────────────

  /// Ajoute [quantity] unités d'une variante au panier.
  ///
  /// Fournir [preview] active la mise à jour optimiste : sans lui (appelant qui
  /// ne connaît que l'identifiant de variante), on retombe sur l'attente du
  /// serveur — correct, simplement pas instantané.
  Future<void> addItem({
    required String variantId,
    int quantity = 1,
    CartItemPreview? preview,
    bool awaitServer = false,
  }) {
    if (preview != null) {
      final refus = validateAddItem(state.value, preview);
      if (refus != null) throw CartException(refus, code: 'INVALID_LOCAL');
    }

    return _muter(
      cle: variantId,
      awaitServer: awaitServer,
      gesteDefait: 'l\'article n\'a pas été ajouté',
      optimiste: preview == null
          ? null
          : (cart) => applyAddItem(cart, preview, quantity),
      envoyer: () async {
        final serveur = await _repo.addToCart(
          variantId: variantId,
          quantity: quantity,
        );
        // `add_to_cart` **après** acceptation par le serveur, jamais sur le
        // geste : il refuse un produit épuisé ou un vendeur fermé, et compter
        // le tap ferait apparaître des ajouts qui n'ont jamais eu lieu. Le
        // rendu étant désormais optimiste, c'est le seul endroit du code où
        // cette distinction existe encore — d'où le déplacement ici, depuis
        // les sept sites d'appel qui la portaient chacun de leur côté.
        if (preview != null) {
          AnalyticsService.trackAddToCart(
            productId: preview.productId,
            productName: preview.product.nom,
            restaurantId: preview.product.restaurantId,
            price: preview.variant.prix,
            quantity: quantity,
          );
        }
        return serveur;
      },
    );
  }

  Future<void> updateItemQuantity({
    required String cartItemId,
    required int quantity,
    bool awaitServer = false,
  }) {
    return _muter(
      cle: cartItemId,
      awaitServer: awaitServer,
      gesteDefait: 'la quantité n\'a pas été modifiée',
      optimiste: (cart) => applySetQuantity(cart, cartItemId, quantity),
      envoyer: () => _repo.updateItemQuantity(
        cartItemId: cartItemId,
        quantity: quantity,
      ),
    );
  }

  Future<void> removeItem({
    required String cartItemId,
    bool awaitServer = false,
  }) {
    return _muter(
      cle: cartItemId,
      awaitServer: awaitServer,
      gesteDefait: 'l\'article n\'a pas été retiré',
      optimiste: (cart) => applyRemoveItem(cart, cartItemId),
      envoyer: () => _repo.removeItem(cartItemId: cartItemId),
    );
  }

  // ─── Mutations sur les menus (sans optimisme, cf. en-tête de classe) ───────

  Future<void> addMenu({required String menuId, int quantity = 1}) => _muter(
    cle: 'menu:$menuId',
    awaitServer: true,
    gesteDefait: 'le menu n\'a pas été ajouté',
    optimiste: null,
    envoyer: () => _repo.addMenuToCart(menuId: menuId, quantity: quantity),
  );

  Future<void> updateMenuQuantity({
    required String menuId,
    required int quantity,
  }) => _muter(
    cle: 'menu:$menuId',
    awaitServer: true,
    gesteDefait: 'la quantité du menu n\'a pas été modifiée',
    optimiste: null,
    envoyer: () =>
        _repo.updateMenuQuantity(menuId: menuId, quantity: quantity),
  );

  Future<void> removeMenu({required String menuId}) => _muter(
    cle: 'menu:$menuId',
    awaitServer: true,
    gesteDefait: 'le menu n\'a pas été retiré',
    optimiste: null,
    envoyer: () => _repo.removeMenu(menuId: menuId),
  );

  // ─── Lecture, vidage, recommande ──────────────────────────────────────────

  /// Vide le panier. L'état vide est appliqué immédiatement : c'est le seul
  /// résultat possible d'un vidage réussi, et l'échec le défait.
  Future<void> clearCart() async {
    final instantane = state.value;
    state = const AsyncData(null);
    try {
      await _repo.clearAllItems();
    } catch (e) {
      if (!ref.mounted) rethrow;
      state = AsyncData(instantane);
      ref
          .read(cartSyncFailuresProvider.notifier)
          .report(_message(e, 'le panier n\'a pas été vidé'));
      rethrow;
    }
  }

  Future<void> refresh() async {
    final serveur = await _repo.getCart();
    if (ref.mounted) state = AsyncData(serveur);
  }

  /// Recommande une commande précédente.
  ///
  /// Aucun optimisme : le contenu ajouté est décidé par le serveur (certains
  /// articles peuvent être indisponibles), le client ne peut pas le deviner.
  Future<Map<String, dynamic>> reorder({required String orderId}) async {
    final result = await _repo.reorderFromOrder(orderId: orderId);
    if (ref.mounted) state = AsyncData(result.cart);
    return result.report;
  }

  /// LIL-122 décision 2a : détecte un conflit de mode entre un produit qu'on
  /// veut ajouter (newMadeToOrder) et le contenu actuel du panier. Renvoie
  /// `true` si l'ajout ferait un panier mixte → le caller doit afficher la
  /// modal "Vider le panier ?" avant d'appeler addItem. Backend bloque aussi
  /// défensivement (CartService.assertSameMadeToOrderMode).
  bool wouldConflictWithCart(bool newMadeToOrder) {
    final cart = state.value;
    if (cart == null || cart.items.isEmpty) return false;
    final existingMode = cart.items.first.product.madeToOrder;
    return existingMode != newMadeToOrder;
  }

  // ─── Mécanique commune ────────────────────────────────────────────────────

  /// Exécute une mutation : application locale immédiate, envoi sérialisé par
  /// clé, adoption ou rejet de la réponse, rollback en cas d'échec.
  Future<void> _muter({
    required String cle,
    required Cart? Function(Cart?)? optimiste,
    required Future<Cart?> Function() envoyer,
    required bool awaitServer,
    required String gesteDefait,
  }) {
    final seq = ++_sequence;
    final instantane = state.value;

    if (optimiste != null) state = AsyncData(optimiste(instantane));

    final termine = _enFile(cle, () async {
      _enVol++;
      _clesEnVol.add(cle);
      // Deux clés mutées en même temps : les réponses décrivent des états
      // serveur qu'on ne peut pas ordonner de façon fiable depuis le client.
      // On le note pour relire une fois le calme revenu.
      if (_clesEnVol.length > 1) _reconciliationRequise = true;

      try {
        final serveur = await envoyer();
        _adopter(seq, serveur);
      } catch (e) {
        _echouer(seq, instantane, optimiste != null, e, gesteDefait);
        rethrow;
      } finally {
        _enVol--;
        _clesEnVol.remove(cle);
        await _reconcilier();
      }
    });

    // Sans optimisme, l'appelant doit attendre : c'est sa seule source de
    // vérité. Avec, il rend la main tout de suite — mais l'erreur ne doit pas
    // remonter comme exception non capturée.
    if (awaitServer || optimiste == null) return termine;
    unawaited(termine.catchError((Object _) {}));
    return Future<void>.value();
  }

  /// Adopte le panier renvoyé par le serveur, **sauf s'il est déjà dépassé**.
  ///
  /// Une réponse n'est adoptée que si aucune mutation n'a été demandée après
  /// elle : sinon, le client a déjà affiché un état plus avancé, et l'écraser
  /// ferait reculer le panier sous les yeux du client avant de le voir
  /// réavancer. La réponse de la dernière mutation, elle, sera adoptée.
  void _adopter(int seq, Cart? serveur) {
    if (!ref.mounted || seq != _sequence) return;

    // ⚠️ `null` n'est **pas** « panier vide ». Les six routes de mutation
    // renvoient toujours un panier ; `null` signifie que la réponse n'a pas pu
    // être lue comme tel. L'adopter viderait le panier à l'écran sur une
    // réponse malformée — un article ajouté avec succès disparaîtrait. On
    // conserve donc l'état optimiste et on ira relire.
    //
    // Un panier réellement vidé arrive sous la forme d'un `Cart` sans article,
    // pas d'un `null` : la distinction est portée par la donnée.
    if (serveur == null) {
      _reconciliationRequise = true;
      return;
    }

    state = AsyncData(serveur);
  }

  /// Défait une mutation qui a échoué.
  ///
  /// Restaurer l'instantané n'est sûr que si cette mutation était **seule** :
  /// sinon l'instantané ignore les autres mutations acceptées entre-temps, et
  /// le restaurer les effacerait de l'écran. Dans ce cas on ne devine pas — on
  /// relit le panier serveur.
  void _echouer(
    int seq,
    Cart? instantane,
    bool etaitOptimiste,
    Object erreur,
    String gesteDefait,
  ) {
    if (!etaitOptimiste) return; // rien n'a été appliqué localement
    // Le panier a pu être détruit pendant que la requête volait : déconnexion,
    // changement de compte, écran quitté. Écrire dans un provider disposé lève,
    // et surtout : cet état ne serait plus celui de personne.
    if (!ref.mounted) return;
    if (_enVol == 1 && seq == _sequence) {
      state = AsyncData(instantane);
    } else {
      _reconciliationRequise = true;
    }
    ref
        .read(cartSyncFailuresProvider.notifier)
        .report(_message(erreur, gesteDefait));
  }

  /// Relit le panier serveur une fois toutes les mutations retombées, et
  /// seulement si quelque chose a pu rendre l'état local incertain.
  ///
  /// Le cas courant — des taps répétés sur un même produit — ne déclenche
  /// **jamais** cette lecture : une seule clé est en jeu, les envois sont
  /// sérialisés, la dernière réponse fait foi.
  Future<void> _reconcilier() async {
    if (_enVol > 0 || !_reconciliationRequise || !ref.mounted) return;
    _reconciliationRequise = false;
    try {
      final serveur = await _repo.getCart();
      if (ref.mounted) state = AsyncData(serveur);
    } catch (_) {
      // La relecture est un confort, pas une obligation : si elle échoue, on
      // garde l'état courant plutôt que de vider le panier à l'écran.
    }
  }

  /// Chaîne les mutations portant la même clé.
  ///
  /// La file ne porte jamais d'erreur : chaque maillon la capture pour son
  /// propre appelant, sans quoi un échec romprait la chaîne et bloquerait
  /// toutes les mutations suivantes de cette variante.
  Future<void> _enFile(String cle, Future<void> Function() operation) {
    final precedente = _files[cle] ?? Future<void>.value();
    final resultat = Completer<void>();

    final maillon = precedente.then((_) async {
      try {
        await operation();
        resultat.complete();
      } catch (e, st) {
        resultat.completeError(e, st);
      }
    });

    _files[cle] = maillon;
    // Libère l'entrée dès que la file de cette clé est retombée au calme.
    maillon.whenComplete(() {
      if (identical(_files[cle], maillon)) _files.remove(cle);
    });

    return resultat.future;
  }

  /// Message d'échec, du point de vue de quelqu'un qui **a déjà vu** son geste
  /// aboutir à l'écran.
  ///
  /// « La requête a pris trop de temps » décrit la panne ; ce qu'il faut dire
  /// ici, c'est que le geste a été défait. Sur les refus métier, le message du
  /// serveur est plus précis que tout ce qu'on pourrait rédiger — on le garde.
  String _message(Object erreur, String gesteDefait) {
    if (erreur is CartException) {
      return switch (erreur.code) {
        'TIMEOUT' => 'Connexion trop lente : $gesteDefait.',
        'NO_INTERNET' => 'Pas de connexion : $gesteDefait.',
        'SERVER_ERROR' => 'Serveur indisponible : $gesteDefait.',
        'UNAUTHENTICATED' => 'Session expirée : $gesteDefait.',
        _ => erreur.message,
      };
    }
    return 'Le panier n\'a pas pu être synchronisé : $gesteDefait.';
  }
}
