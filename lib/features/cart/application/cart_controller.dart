import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/data/guest_cart_store.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/services/analytics_service.dart';

part 'cart_controller.g.dart';

// Maintenu en vie : lu par des contrôleurs qui le sont (panier, adresses,
// profil, session). Sans état propre, il ne dépend que d'`apiClient`, lui-même
// maintenu en vie — le garder ne coûte rien, le recréer sous un contrôleur
// vivant est ce que `only_use_keep_alive_inside_keep_alive` interdit.
@Riverpod(keepAlive: true)
CartRepository cartRepository(Ref ref) =>
    CartRepository(ref.watch(apiClientProvider));

/// « Y a-t-il une session ouverte ? », posée **au moment du geste**.
///
/// Une fonction et non un booléen, délibérément. Un booléen dérivé de
/// `authStateChangeProvider` rendrait `CartController.build()` réactif à la
/// connexion — donc le panier serveur écraserait le panier du visiteur à la
/// seconde où la session s'ouvre, **avant** que `adoptGuestCart` ait pu le
/// verser. La transition est un geste explicite, pas un effet de bord de
/// reconstruction.
///
/// C'est aussi le seul point d'injection des tests : ils exercent le panier
/// serveur sans Firebase initialisé.
@Riverpod(keepAlive: true)
bool Function() cartSessionIsOpen(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  return () => auth.currentUser != null;
}

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
  Future<Cart?> build() async {
    // Le magasin local n'est touché que sans session : `SharedPreferences`
    // exige un binding Flutter initialisé, et un client connecté n'a rien à y
    // lire.
    if (_sansSession) {
      final magasin = await ref.watch(guestCartStoreProvider.future);
      return magasin.read();
    }
    return ref.watch(cartRepositoryProvider).getCart();
  }

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  /// Personne n'est connecté.
  ///
  /// Lu à chaque mutation plutôt que capturé une fois : la session peut
  /// s'ouvrir pendant la vie du contrôleur (c'est même tout l'intérêt), et un
  /// booléen figé enverrait les gestes suivants au mauvais endroit.
  bool get _sansSession => !ref.read(cartSessionIsOpenProvider)();

  // ─── Panier du visiteur ───────────────────────────────────────────────────

  /// Cet échec parle-t-il du transport, ou de l'article ?
  ///
  /// `CartRepository` mappe les deux mondes vers le même type. Les codes
  /// ci-dessous décrivent une indisponibilité du **service** : elle vaut pour
  /// toutes les lignes, pas pour celle qu'on essayait de verser.
  static bool _estPanneDeTransport(CartException e) => const {
    'NO_INTERNET',
    'TIMEOUT',
    'SERVER_ERROR',
    'UNAUTHENTICATED',
  }.contains(e.code);

  /// Applique une mutation **localement**, pour un visiteur sans compte.
  ///
  /// Même fonction pure que l'affichage optimiste du panier serveur : il n'y a
  /// qu'une seule notion de panier dans l'application, et un seul code qui la
  /// fait évoluer. La seule différence est la destination — `SharedPreferences`
  /// au lieu de `POST /cart/*`.
  Future<void> _muterLocalement(
    Cart? Function(Cart?)? optimiste,
    String gesteDefait,
  ) async {
    // Un geste dont on ne sait pas produire le résultat localement ne peut pas
    // être joué sans le serveur — donc pas sans session.
    //
    // En pratique il n'en reste qu'un : l'ajout d'un menu dont la
    // décomposition n'a pas été fournie, ou qui n'est pas décomposable (un
    // produit sans variante — le serveur le refuse aussi). Le cas nominal, lui,
    // passe par `MenuCartPreview.fromMenu` et fonctionne sans compte.
    if (optimiste == null) {
      throw CartException(
        'Connectez-vous pour ajouter ce menu à votre panier.',
        code: 'AUTH_REQUIRED',
      );
    }

    // ⚠️ Attendre que le panier stocké soit LU avant de muter par-dessus.
    //
    // `build()` est asynchrone hors session : il lit `SharedPreferences`.
    // Tant qu'il n'a pas rendu, `state.value` vaut `null` — indiscernable
    // d'un panier vide. Un geste joué dans cette fenêtre produisait un panier
    // d'un seul article, **et le réécrivait dans le magasin** : le panier
    // composé la veille disparaissait.
    //
    // La fenêtre est courte — le badge de la coque observe le panier dès le
    // montage, donc le `build()` part au démarrage — mais elle s'ouvre sur un
    // démarrage à froid suivi d'un tap rapide, et sur un premier accès disque
    // lent. C'est exactement le profil d'un téléphone d'entrée de gamme.
    //
    // `state.value` quand il existe, `await future` sinon : on ne paie
    // l'attente que la première fois.
    final actuel = state.hasValue ? state.value : await future;
    final nouveau = optimiste(actuel);
    if (!ref.mounted) return;
    state = AsyncData(nouveau);
    try {
      final magasin = await ref.read(guestCartStoreProvider.future);
      await magasin.write(nouveau);
    } catch (e) {
      // L'écriture locale a échoué : le panier reste juste à l'écran pour
      // cette session, mais il ne survivra pas à la fermeture. On le dit —
      // c'est exactement le genre de perte silencieuse qu'on cherche à éviter.
      ref
          .read(cartSyncFailuresProvider.notifier)
          .report(_message(e, gesteDefait));
    }
  }

  /// Verse le panier du visiteur dans son panier serveur, à la connexion.
  ///
  /// ## Le conflit, et la règle retenue
  ///
  /// Un client peut arriver avec **deux** paniers : celui qu'il vient de
  /// composer en visiteur, et celui que son compte avait laissé ouvert. La
  /// règle est *le panier du visiteur gagne* :
  ///
  /// - c'est celui qu'il est en train de regarder, au moment où il se connecte
  ///   **pour le commander** — le second est un reliquat d'une autre session ;
  /// - les deux ne sont pas fusionnables quand ils viennent de vendeurs
  ///   différents, ou mélangent produits immédiats et produits sur commande :
  ///   le serveur refuse ces paniers (`validateAddItem` porte la même règle).
  ///   Il faut donc en choisir un, et prendre l'ancien effacerait un geste
  ///   délibéré au profit d'un oubli.
  ///
  /// Quand les deux sont compatibles (même vendeur, même mode), rien n'est
  /// effacé : les lignes du visiteur s'**ajoutent**, et les quantités
  /// s'additionnent — c'est ce que fait `POST /cart/add`.
  ///
  /// ## En cas d'échec
  ///
  /// Le panier local est **conservé**. Il n'est effacé qu'après avoir été
  /// réellement versé : un réseau coupé au mauvais moment ne doit pas faire
  /// disparaître ce que le client a composé.
  Future<void> adoptGuestCart() async {
    final magasin = await ref.read(guestCartStoreProvider.future);
    final invite = magasin.read();

    if (invite == null || invite.items.isEmpty) {
      await refresh();
      return;
    }

    try {
      final serveur = await _repo.getCart();

      // Le serveur refuse un panier à deux vendeurs ou à deux modes. On pose
      // la question avec la règle existante plutôt qu'en recopiant ses deux
      // conditions : elles évolueraient séparément.
      final incompatible =
          validateAddItem(serveur, CartItemPreview.fromCartItem(invite.items.first)) !=
          null;
      if (incompatible) await _repo.clearAllItems();

      // ── Ligne par ligne, et non tout ou rien ──────────────────────────────
      //
      // Le catalogue a pu bouger pendant que le visiteur composait : un produit
      // épuisé, retiré, ou sorti de sa fenêtre horaire fait échouer SON ajout
      // — pas les autres. Abandonner le versement entier sur le premier refus
      // renverrait quelqu'un qui a cinq articles valables à un panier vide,
      // pour une rupture sur le sixième.
      //
      // Les refusés restent en local, et ils sont **nommés** : « ce n'est pas
      // passé » sans dire quoi oblige à comparer deux écrans de mémoire.
      Cart? resultat = incompatible ? null : serveur;
      final refuses = <CartItem>[];

      for (final ligne in invite.items) {
        try {
          resultat = await _repo.addToCart(
            variantId: ligne.variantId,
            quantity: ligne.quantite,
          );
        } on CartException catch (e) {
          // ⚠️ Toutes les `CartException` ne se valent pas. Un réseau coupé
          // remonte par le même type qu'un produit épuisé — les traiter pareil
          // marquerait « n'est plus disponible » sur tout ce qui reste à
          // verser, au moment précis où rien n'est disponible parce que rien ne
          // part. On rejette vers le `catch` extérieur, qui conserve le panier
          // entier et dit la vérité : ça n'a pas pu être repris.
          if (_estPanneDeTransport(e)) rethrow;
          // Refus métier (stock, disponibilité, fenêtre horaire) : il concerne
          // cette ligne seule.
          refuses.add(ligne);
        }
      }

      // Le magasin ne garde QUE ce qui n'est pas passé. Le vider entièrement
      // perdrait les refus ; ne rien vider les ferait revenir en double au
      // prochain démarrage.
      await magasin.write(
        refuses.isEmpty ? null : invite.copyWith(items: refuses),
      );
      if (ref.mounted) state = AsyncData(resultat);

      if (refuses.isNotEmpty) {
        final noms = refuses.map((i) => i.product.nom).join(', ');
        ref
            .read(cartSyncFailuresProvider.notifier)
            .report(
              refuses.length == 1
                  ? '$noms n\'est plus disponible et n\'a pas été repris.'
                  : 'Ces articles ne sont plus disponibles et n\'ont pas été '
                        'repris : $noms.',
            );
      }
    } catch (e) {
      // Panne réseau ou refus global : le panier local survit **en entier**,
      // le client le retrouvera au prochain essai.
      ref
          .read(cartSyncFailuresProvider.notifier)
          .report(
            _message(e, 'votre panier n\'a pas pu être repris — il est conservé'),
          );
      await refresh();
    }
  }

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

  /// Ajoute un menu complet au panier.
  ///
  /// [preview] décrit sa décomposition en lignes — une par produit, la première
  /// variante de chacun, comme le fait `CartMenusService`. Le fournir rend le
  /// menu disponible **aux visiteurs sans compte** : sans lui, on retombe sur
  /// l'ajout serveur, qui exige une session.
  ///
  /// `null` reste accepté pour les appelants qui ne connaissent que
  /// l'identifiant du menu : correct, simplement réservé aux connectés.
  Future<void> addMenu({
    required String menuId,
    int quantity = 1,
    MenuCartPreview? preview,
  }) {
    // Même arbitrage que pour un article : un menu dont un produit vient d'un
    // autre vendeur, ou d'un autre mode, ne peut pas rejoindre ce panier.
    if (preview != null) {
      final refus = validateAddItem(state.value, preview.lines.first);
      if (refus != null) throw CartException(refus, code: 'INVALID_LOCAL');
    }

    return _muter(
      cle: 'menu:$menuId',
      awaitServer: true,
      gesteDefait: 'le menu n\'a pas été ajouté',
      optimiste: preview == null
          ? null
          : (cart) => applyAddMenu(cart, preview, quantity),
      envoyer: () => _repo.addMenuToCart(menuId: menuId, quantity: quantity),
    );
  }

  Future<void> updateMenuQuantity({
    required String menuId,
    required int quantity,
  }) => _muter(
    cle: 'menu:$menuId',
    awaitServer: true,
    gesteDefait: 'la quantité du menu n\'a pas été modifiée',
    // Modifier la quantité d'un menu ne demande aucune connaissance du
    // catalogue : les lignes sont déjà dans le panier. Un visiteur peut donc
    // le faire, contrairement à l'ajout.
    optimiste: (cart) => applySetMenuQuantity(cart, menuId, quantity),
    envoyer: () =>
        _repo.updateMenuQuantity(menuId: menuId, quantity: quantity),
  );

  Future<void> removeMenu({required String menuId}) => _muter(
    cle: 'menu:$menuId',
    awaitServer: true,
    gesteDefait: 'le menu n\'a pas été retiré',
    optimiste: (cart) => applyRemoveMenu(cart, menuId),
    envoyer: () => _repo.removeMenu(menuId: menuId),
  );

  // ─── Lecture, vidage, recommande ──────────────────────────────────────────

  /// Vide le panier. L'état vide est appliqué immédiatement : c'est le seul
  /// résultat possible d'un vidage réussi, et l'échec le défait.
  Future<void> clearCart() async {
    final instantane = state.value;
    state = const AsyncData(null);

    if (_sansSession) {
      // ⚠️ Le chemin visiteur n'avait aucun rattrapage, contrairement au
      // chemin connecté juste en dessous. Une écriture locale qui échoue —
      // `SharedPreferences` indisponible, stockage plein — laissait l'écran
      // vide au-dessus d'un magasin toujours plein : le panier « réapparaît »
      // à la relance, sans que rien ne l'ait annoncé.
      //
      // Même conduite que le panier serveur : on défait, et on le dit.
      try {
        final magasin = await ref.read(guestCartStoreProvider.future);
        await magasin.clear();
      } catch (e) {
        if (!ref.mounted) rethrow;
        state = AsyncData(instantane);
        ref
            .read(cartSyncFailuresProvider.notifier)
            .report(_message(e, 'le panier n\'a pas été vidé'));
        rethrow;
      }
      return;
    }

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

  /// Vide le panier **sans que l'appelant ait à attendre ni à rattraper**.
  ///
  /// [clearCart] relève son erreur après avoir défait l'état optimiste, parce
  /// que ses appelants synchrones (l'écran du panier, l'enregistrement d'un
  /// brouillon) en ont besoin pour arrêter leur indicateur. Six autres sites
  /// l'appelaient **sans `await` et sans `catch`** — confirmation de paiement,
  /// écran de succès, reprise après échec. Une `Future` rejetée sans
  /// gestionnaire devient une erreur asynchrone non capturée : un événement
  /// Sentry à chaque `DELETE /cart/clear` qui échoue, au pire moment — le
  /// paiement vient d'aboutir et l'écran navigue vers la confirmation.
  ///
  /// Le motif de l'échec, lui, part déjà dans [cartSyncFailuresProvider] :
  /// le client est informé de toute façon, l'exception ne servait plus à rien
  /// une fois arrivée là.
  void clearCartEnArrierePlan() {
    unawaited(clearCart().catchError((Object _) {}));
  }

  Future<void> refresh() async {
    if (_sansSession) {
      final magasin = await ref.read(guestCartStoreProvider.future);
      if (ref.mounted) state = AsyncData(magasin.read());
      return;
    }
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
    // Visiteur : tout se joue localement, il n'y a pas de panier serveur à
    // synchroniser. Le branchement est ici — un seul endroit — plutôt que dans
    // chacune des six mutations.
    if (_sansSession) return _muterLocalement(optimiste, gesteDefait);

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
