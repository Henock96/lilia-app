// Les effets de session — **le câblage, pas les méthodes.**
//
// C'est la distinction qui compte ici. `guest_cart_test.dart` couvrait déjà
// `adoptGuestCart()` sous tous ses angles… en l'appelant à la main. La méthode
// était donc verte pendant que rien ne la déclenchait jamais : le panier d'un
// visiteur qui se connecte n'était pas repris, et aucun jeton FCM n'était
// enregistré pour une session ouverte en cours d'exécution.
//
// Aucun test de ce fichier n'appelle `adoptGuestCart()` ni
// `registerTokenOnServer()`. Ils font tous la seule chose qui prouve quelque
// chose : **faire basculer la session Firebase**, et regarder ce qui s'est
// produit tout seul.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/application/session_effects.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/data/guest_cart_store.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_repository.dart';

/// Panier serveur simulé, qui applique réellement les ajouts : on observe le
/// contenu obtenu, pas un nombre d'appels.
class _FauxPanierServeur implements CartRepository {
  Cart? _cart;
  Object? erreurAAjout;

  @override
  Future<Cart?> getCart() async => _cart;

  @override
  Future<Cart?> addToCart({
    required String variantId,
    required int quantity,
  }) async {
    if (erreurAAjout != null) throw erreurAAjout!;
    _cart = applyAddItem(
      _cart,
      CartItemPreview(
        productId: 'prod-$variantId',
        variantId: variantId,
        product: ProductItem(nom: variantId, restaurantId: 'resto-1'),
        variant: VariantItem(label: 'Standard', prix: 3500),
      ),
      quantity,
    );
    return _cart;
  }

  @override
  Future<void> clearAllItems() async => _cart = null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

/// Service de notifications simulé — il ne compte que ce qui l'intéresse :
/// combien de fois le jeton a été proposé au serveur.
class _FauxNotifications implements NotificationService {
  int enregistrements = 0;
  int oublis = 0;
  Object? erreur;

  @override
  Future<void> registerTokenOnServer({int maxRetries = 5}) async {
    enregistrements++;
    if (erreur != null) throw erreur!;
  }

  @override
  void forgetRegisteredToken() => oublis++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

/// Une ligne telle que le magasin local la stocke.
Map<String, dynamic> _ligneStockee(String variantId) => CartItem(
      id: optimisticItemId(variantId),
      cartId: GuestCartStore.localCartId,
      productId: 'prod-$variantId',
      variantId: variantId,
      quantite: 1,
      createdAt: DateTime(2026, 9, 20),
      product: ProductItem(nom: 'Produit $variantId', restaurantId: 'resto-1'),
      variant: VariantItem(label: 'Normale', prix: 3500),
    ).toMap();

String _panierInvite(List<String> variantIds) =>
    '{"items":${_jsonListe(variantIds)}}';

String _jsonListe(List<String> variantIds) {
  final lignes = variantIds.map((v) {
    final m = _ligneStockee(v);
    return '{"id":"${m["id"]}","cartId":"${m["cartId"]}",'
        '"productId":"${m["productId"]}","variantId":"${m["variantId"]}",'
        '"menuId":null,"quantite":${m["quantite"]},'
        '"createdAt":"${m["createdAt"]}",'
        '"product":{"nom":"x","imageUrl":null,"restaurantId":"resto-1",'
        '"madeToOrder":false},'
        '"variant":{"label":"Normale","prix":3500},"menu":null}';
  });
  return '[${lignes.join(',')}]';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository auth;
  late _FauxPanierServeur panierServeur;
  late _FauxNotifications notifications;
  late ProviderContainer container;

  /// Laisse retomber les micro-tâches : l'écoute de session est synchrone, les
  /// effets qu'elle lance ne le sont pas.
  Future<void> pompes() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await container.read(sessionEffectsProvider.notifier).enCours;
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Monte l'application telle que `MyApp` la monte : `sessionEffectsProvider`
  /// **observé**, et rien d'autre. C'est très exactement la ligne dont
  /// l'absence produisait les deux P0.
  Future<void> demarrer({
    AppUser? sessionInitiale,
    String? panierInviteBrut,
  }) async {
    SharedPreferences.setMockInitialValues({
      GuestCartStore.storageKey: ?panierInviteBrut,
    });
    auth = FakeAuthRepository(user: sessionInitiale);
    panierServeur = _FauxPanierServeur();
    notifications = _FauxNotifications();

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        cartRepositoryProvider.overrideWithValue(panierServeur),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    // ⚠️ Pas de `auth.dispose()` : fermer le `StreamController` alors qu'un
    // `Stream.multi` y est encore abonné ne rend jamais la main, et le test
    // expire dans son `tearDown`. Aucun des quatorze autres fichiers qui
    // utilisent ce double ne l'appelle — le conteneur Riverpod se défait, les
    // abonnements avec.

    // `listen` et non `read` : un provider que personne n'écoute est mis en
    // pause par Riverpod 3, et son écoute du flux de session ne reçoit rien.
    // Lire sans écouter ne reproduirait pas l'application — c'est la même
    // précaution que `router_lifecycle_test`.
    addTearDown(container.listen(sessionEffectsProvider, (_, _) {}).close);
    addTearDown(container.listen(cartControllerProvider, (_, _) {}).close);
    await pompes();
  }

  Future<GuestCartStore> magasin() =>
      container.read(guestCartStoreProvider.future);

  // ───────────────────────────────────────────────────────────────────────────

  group('P0-001 — le panier du visiteur est repris à l’ouverture de session', () {
    test('1 — panier composé sans compte, puis connexion', () async {
      await demarrer(panierInviteBrut: _panierInvite(['var-1', 'var-2']));

      // Avant : rien côté serveur, deux lignes en local.
      expect(await panierServeur.getCart(), isNull);
      expect((await magasin()).read()?.items, hasLength(2));

      auth.emitSession(const AppUser(uid: 'uid-a', email: 'a@lilia.cg'));
      await pompes();

      final serveur = await panierServeur.getCart();
      expect(
        serveur?.items.map((i) => i.variantId),
        containsAll(<String>['var-1', 'var-2']),
        reason: 'les deux lignes doivent avoir été versées côté serveur',
      );
      expect(
        (await magasin()).read(),
        isNull,
        reason: 'le magasin local n’est vidé qu’une fois le versement abouti',
      );
    });

    test('2 — inscription : même transition, même reprise', () async {
      await demarrer(panierInviteBrut: _panierInvite(['var-1']));

      // `createUserWithEmailAndPassword` émet la session comme le vrai dépôt :
      // Firebase connecte AVANT `/users/sync`.
      await auth.createUserWithEmailAndPassword(
        email: 'neuf@lilia.cg',
        password: 'motdepasse',
        name: 'Neuf',
        phone: '060000000',
      );
      await pompes();

      expect((await panierServeur.getCart())?.items, hasLength(1));
      expect((await magasin()).read(), isNull);
    });

    test('Google : la reprise ne dépend pas du fournisseur d’identité', () async {
      await demarrer(panierInviteBrut: _panierInvite(['var-1', 'var-2']));

      await auth.signInWithGoogle();
      await pompes();

      expect(
        (await panierServeur.getCart())?.items.map((i) => i.variantId),
        containsAll(<String>['var-1', 'var-2']),
      );
      expect((await magasin()).read(), isNull);
      expect(notifications.enregistrements, 1);
    });

    // Il n'y a **pas** de test « Apple ». Apple Sign-In n'est pas implémenté
    // dans cette application : `lib/` ne contient ni `sign_in_with_apple`, ni
    // `OAuthProvider('apple.com')`, ni aucun bouton correspondant. Écrire un
    // test qui émettrait une session « Apple » depuis le double ne
    // prouverait rien de plus que celui du dessus — il donnerait seulement
    // l'impression qu'une capacité absente est couverte.
    //
    // Ce que le test Google établit, et qui vaut pour tout fournisseur futur :
    // l'effet est accroché à la **transition de session**, pas au moyen
    // d'authentification. Le jour où Apple sera ajouté, il passera par
    // `authStateChanges()` comme les deux autres, et la reprise suivra sans
    // qu'une ligne de `SessionEffects` change.

    test('4 — une seconde adoption ne duplique rien', () async {
      await demarrer(panierInviteBrut: _panierInvite(['var-1']));

      auth.emitSession(const AppUser(uid: 'uid-a'));
      await pompes();
      expect((await panierServeur.getCart())?.items, hasLength(1));

      // Deuxième appel explicite — ce que produirait une réémission du flux,
      // un rappel manuel, ou deux chemins de connexion qui se croisent.
      await container.read(cartControllerProvider.notifier).adoptGuestCart();
      await pompes();

      expect(
        (await panierServeur.getCart())?.items,
        hasLength(1),
        reason: 'le magasin ayant été vidé au premier versement, le second '
            'n’a plus rien à verser : la quantité ne doit pas doubler',
      );
      expect(
        (await panierServeur.getCart())?.items.first.quantite,
        1,
        reason: 'ni la ligne, ni sa quantité',
      );
    });

    test('session restaurée au démarrage : la reprise a lieu aussi', () async {
      // Un visiteur compose son panier, tue l’application, la relance alors
      // qu’une session était déjà ouverte : il n’y a pas de « transition »,
      // seulement une première émission. Elle doit compter.
      await demarrer(
        sessionInitiale: const AppUser(uid: 'uid-a'),
        panierInviteBrut: _panierInvite(['var-1']),
      );

      expect((await panierServeur.getCart())?.items, hasLength(1));
      expect(notifications.enregistrements, 1);
    });

    test('un versement en échec CONSERVE le panier local', () async {
      await demarrer(panierInviteBrut: _panierInvite(['var-1']));
      panierServeur.erreurAAjout = CartException(
        'Pas de connexion internet.',
        code: 'NO_INTERNET',
      );

      auth.emitSession(const AppUser(uid: 'uid-a'));
      await pompes();

      expect(
        (await magasin()).read()?.items,
        hasLength(1),
        reason: 'une panne réseau ne doit jamais effacer ce que le client a composé',
      );
    });
  });

  group('P0-002 — le jeton FCM est rattaché à l’ouverture de session', () {
    test('3 — jeton enregistré à la connexion', () async {
      await demarrer();
      expect(notifications.enregistrements, 0);

      auth.emitSession(const AppUser(uid: 'uid-a'));
      await pompes();

      expect(notifications.enregistrements, 1);
    });

    test('un enregistrement en échec ne fait pas échouer la session', () async {
      await demarrer();
      notifications.erreur = StateError('FCM indisponible');

      auth.emitSession(const AppUser(uid: 'uid-a'));
      await pompes();

      // La session est ouverte, et le panier a quand même été traité.
      expect(auth.currentUser, isNotNull);
      expect(notifications.enregistrements, 1);
    });
  });

  group('transitions', () {
    test('5 — A se déconnecte, B se connecte : rien de A ne suit', () async {
      await demarrer(sessionInitiale: const AppUser(uid: 'uid-a'));
      await pompes();

      // A compose un panier côté serveur.
      await panierServeur.addToCart(variantId: 'var-de-A', quantity: 1);
      expect((await panierServeur.getCart())?.items, hasLength(1));

      await auth.signOut();
      await pompes();
      expect(
        notifications.oublis,
        greaterThanOrEqualTo(1),
        reason: 'le rattachement du jeton au compte parti doit être oublié',
      );

      auth.emitSession(const AppUser(uid: 'uid-b'));
      await pompes();

      // Le panier de B est relu depuis le serveur, pas hérité d’un état local.
      // Aucun panier invité n’existe : rien n’a été versé pour B.
      expect((await magasin()).read(), isNull);
      // Et le jeton a bien été réenregistré pour B, malgré une valeur
      // inchangée côté appareil.
      expect(notifications.enregistrements, 2);
    });

    // ── Le panier du visiteur ne doit pas attendre le compte suivant ────────
    //
    // `guest_cart_v1` est **globale**, délibérément : tout le mode visiteur
    // repose sur le fait que le panier survive à la connexion pour être versé
    // (`user_scoped_prefs.dart`). Ce raisonnement ne vaut que dans un sens.
    //
    // À la déconnexion, le magasin peut ne pas être vide : `adoptGuestCart`
    // conserve volontairement les lignes refusées, et conserve le panier
    // ENTIER sur panne réseau. Ces lignes appartiennent à celui qui vient de
    // partir, et sur un téléphone partagé — cas courant à Brazzaville — le
    // suivant se les voit verser dans son propre panier serveur.
    test('7 — le panier du visiteur ne traverse pas un changement de compte',
        () async {
      // A compose un panier sans compte, puis se connecte — mais le réseau
      // tombe pendant le versement. Ses lignes restent dans le magasin local,
      // c'est la garantie de `adoptGuestCart` et elle est juste.
      await demarrer(panierInviteBrut: _panierInvite(['var-de-A']));
      panierServeur.erreurAAjout = CartException(
        'Pas de connexion internet.',
        code: 'NO_INTERNET',
      );

      auth.emitSession(const AppUser(uid: 'uid-a'));
      await pompes();
      expect(
        (await magasin()).read()?.items,
        hasLength(1),
        reason: 'préalable : l’échec réseau conserve bien le panier local',
      );

      await auth.signOut();
      await pompes();

      expect(
        (await magasin()).read(),
        isNull,
        reason: 'le panier de A ne doit pas rester à disposition du visiteur '
            'suivant sur ce téléphone',
      );

      // B arrive : rien à verser, donc rien de A dans son panier.
      panierServeur.erreurAAjout = null;
      auth.emitSession(const AppUser(uid: 'uid-b'));
      await pompes();

      expect(
        (await panierServeur.getCart())?.items ?? const [],
        isEmpty,
        reason: 'B ne doit pas se retrouver à pouvoir payer les articles de A',
      );
    });

    test('un démarrage sans session ne touche pas au panier du visiteur',
        () async {
      // Le cas nominal du mode visiteur : personne ne s'est déconnecté, il n'y
      // a rien à purger. Effacer ici reviendrait à casser la fonctionnalité
      // qu'on protège.
      await demarrer(panierInviteBrut: _panierInvite(['var-1']));

      expect((await magasin()).read()?.items, hasLength(1));
    });

    test('6 — une même session réémise ne relance aucun effet', () async {
      await demarrer();

      const utilisateur = AppUser(uid: 'uid-a');
      auth.emitSession(utilisateur);
      await pompes();
      expect(notifications.enregistrements, 1);

      // Firebase réémet volontiers la même session : réabonnement, retour au
      // premier plan, rafraîchissement interne du jeton.
      auth.emitSession(const AppUser(uid: 'uid-a', email: 'maj@lilia.cg'));
      auth.emitSession(const AppUser(uid: 'uid-a'));
      await pompes();

      expect(
        notifications.enregistrements,
        1,
        reason: 'seul un changement d’identifiant est une transition',
      );
    });

    test('démarrage sans session : aucun effet, aucun nettoyage', () async {
      await demarrer();

      expect(notifications.enregistrements, 0);
      expect(
        notifications.oublis,
        0,
        reason: 'il n’y avait pas de session à fermer',
      );
    });
  });
}
