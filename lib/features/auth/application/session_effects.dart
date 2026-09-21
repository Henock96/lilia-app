import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';
import '../../../services/notification_service.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/data/guest_cart_store.dart';
import '../app_user_model.dart';
import '../repository/firebase_auth_repository.dart';
import 'user_scoped_providers.dart';
import 'package:lilia_app/core/log.dart';

part 'session_effects.g.dart';

/// **Ce qui se produit quand une session s'ouvre, et quand elle se ferme.**
///
/// ## Le défaut que ce fichier corrige
///
/// Ces effets vivaient dans `AuthController.build()`, dans une écoute posée à
/// la main sur `authStateChanges()`. Le raisonnement était juste — la reprise
/// du panier et l'enregistrement du jeton appartiennent à la **transition de
/// session**, pas à un écran, parce que la connexion peut venir de six
/// endroits et que chacun oublierait tôt ou tard de le faire.
///
/// Mais `authControllerProvider` n'était observé par **aucun** écran au
/// démarrage : le seul `ref.watch` de toute l'application est dans
/// `edit_profile_page.dart`. Les providers Riverpod étant paresseux,
/// `AuthController.build()` ne s'exécutait qu'au premier
/// `ref.read(...notifier)` — c'est-à-dire à la déconnexion, à la suppression
/// de compte, ou sur un 401. **Jamais à la connexion.**
///
/// Conséquences mesurées :
///
/// * le panier composé sans compte n'était jamais versé dans le panier du
///   compte : `POST /orders/checkout` répondait « panier vide » à un client
///   dont l'écran affichait un panier plein ;
/// * aucun jeton FCM n'était enregistré pour une session ouverte en cours
///   d'exécution — la première commande de chaque nouvel utilisateur se
///   déroulait sans une seule notification.
///
/// ## Aucun nouvel abonnement Firebase
///
/// C'est la contrainte qui décide de la forme. L'application compte **un**
/// abonnement à `authStateChanges()` qui soit réellement actif :
/// `authStateChangeProvider`, observé par `sessionPhaseProvider`, lui-même
/// observé par `routerProvider`, lui-même observé par `MyApp`. Ce provider est
/// donc vivant pour toute la durée de l'application, et Riverpod partage son
/// unique souscription entre tous ses auditeurs.
///
/// ```text
/// FirebaseAuth.authStateChanges()        ← UNE souscription
///        │
///        └─ authStateChangeProvider      (keepAlive)
///             ├─ sessionPhaseProvider → routerProvider → MyApp
///             └─ sessionEffectsProvider → MyApp          ← ce fichier
/// ```
///
/// `AuthController` s'y branchait **deux fois** (une écoute manuelle *et* le
/// `Stream` rendu, que Riverpod souscrit à son tour). Ce doublon a disparu :
/// le contrôleur ne raconte plus que la session, conformément à son propre
/// en-tête.
///
/// ## Déduplication
///
/// Un flux d'authentification réémet volontiers la même session (réabonnement,
/// rafraîchissement interne). Seul un **changement d'identifiant** déclenche un
/// effet, et [_amorce] distingue « première émission » de « aucun changement ».
///
/// | Transition | Effet |
/// |---|---|
/// | `null → A` (connexion, inscription) | ouverture |
/// | `∅ → A` (session restaurée au démarrage) | ouverture |
/// | `A → A` (réémission) | **rien** |
/// | `A → null` (déconnexion) | fermeture |
/// | `A → null → B` (changement de compte) | fermeture puis ouverture |
/// | `∅ → null` (démarrage sans session) | **rien** |
@Riverpod(keepAlive: true)
class SessionEffects extends _$SessionEffects {
  /// Identifiant de la session observée en dernier. `null` = personne.
  String? _uidCourant;

  /// Vrai dès la première émission traitée. Sans lui, `_uidCourant == null` à
  /// l'amorçage serait indiscernable d'une déconnexion, et un démarrage sans
  /// session déclencherait un nettoyage qui n'a rien à nettoyer.
  bool _amorce = false;

  Future<void>? _enCours;

  @override
  void build() {
    ref.listen<AsyncValue<AppUser?>>(
      authStateChangeProvider,
      (_, next) {
        // Une **erreur** du flux ne signifie pas « déconnecté » : elle signifie
        // qu'on ne sait pas. `sessionPhase` la traite comme déconnecté pour
        // pouvoir router quelque part — ici il n'y a rien à router, et vider
        // les données d'un compte sur une panne de lecture serait un dégât
        // gratuit. On attend la prochaine émission utile.
        final session = next.value;
        if (next.hasValue) _surSession(session);
      },
      fireImmediately: true,
    );
  }

  void _surSession(AppUser? utilisateur) {
    final uid = utilisateur?.uid;
    if (_amorce && uid == _uidCourant) return;

    final precedent = _uidCourant;
    final dejaAmorce = _amorce;
    _uidCourant = uid;
    _amorce = true;

    if (uid == null) {
      // Démarrage sans session : il n'y a pas eu de session à fermer.
      if (precedent != null) _lancer(_fermeture);
      return;
    }
    // « Restaurée » = l'application s'est ouverte sur une session déjà en
    // cours, par opposition à une connexion faite depuis l'écran. La
    // distinction ne sert qu'au rangement des données locales héritées, où
    // elle est déterminante — voir `rangerDonneesHeritees`.
    final restauree = precedent == null && !dejaAmorce;
    _lancer(() => _ouverture(sessionRestauree: restauree, uid: uid));
  }

  /// Enchaîne les effets sans jamais les laisser remonter.
  ///
  /// L'appelant est une écoute **synchrone** : une exception y deviendrait une
  /// erreur asynchrone non capturée. Et surtout, aucun de ces effets n'est une
  /// condition d'ouverture de session — ne pas recevoir de notifications ne
  /// doit jamais empêcher de se connecter.
  void _lancer(Future<void> Function() effet) {
    _enCours = Future<void>(effet).catchError((Object e) {
      if (kDebugMode) logDebug('Effet de session en échec : ${e.runtimeType}');
    });
  }

  /// Le dernier effet déclenché.
  ///
  /// Exposé pour les tests : ils doivent pouvoir attendre un effet lancé depuis
  /// une écoute synchrone, sans quoi ils observeraient l'état d'avant.
  @visibleForTesting
  Future<void> get enCours => _enCours ?? Future<void>.value();

  // ─── Ouverture ────────────────────────────────────────────────────────────

  Future<void> _ouverture({
    required bool sessionRestauree,
    required String uid,
  }) async {
    // Le rangement d'abord : il est local, instantané, et les providers
    // lisent leur magasin dès qu'un écran les observe.
    await _rangerDonneesHeritees(uid: uid, sessionRestauree: sessionRestauree);

    // ⚠️ Invalider **aussi à l'ouverture**, et pas seulement à la fermeture.
    //
    // Les magasins locaux sont rangés par compte (`favorites__<uid>`), et la
    // clé est résolue au `build` du provider. Or rien ne reconstruit ces
    // providers quand la session s'ouvre : `authRepositoryProvider` est un
    // `Provider` dont la valeur ne change pas à la connexion — seul son
    // `currentUser` change, ce que Riverpod ne voit pas.
    //
    // Mesuré : un visiteur met un produit en favori (`favorites__invite`),
    // se connecte, et le provider continue de lire — et d'écrire — le seau du
    // visiteur. Ses favoris apparaissent comme ceux du compte, et ses propres
    // favoris resteraient invisibles.
    //
    // Le panier est **exclu** : `adoptGuestCart` s'en occupe juste après, et
    // le relire en parallèle ferait courir deux écritures l'une après l'autre
    // (voir `invalidateUserScopedProviders`).
    invalidateUserScopedProviders(ref, inclureLePanier: false);
    // Puis le panier : c'est celui que le client regarde, et il vient souvent
    // de se connecter **pour le commander**. L'enregistrement du jeton peut
    // attendre un aller-retour de plus.
    await _reprendrePanierInvite();
    await _enregistrerJetonPush();
  }

  /// Traite une fois pour toutes les magasins locaux écrits sous une clé
  /// globale par les versions précédentes. Voir `user_scoped_prefs.dart` pour
  /// le raisonnement — en particulier pourquoi une migration inconditionnelle
  /// rouvrirait la fuite qu'on vient de fermer.
  Future<void> _rangerDonneesHeritees({
    required String uid,
    required bool sessionRestauree,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await rangerDonneesHeritees(
        prefs,
        uid: uid,
        sessionRestauree: sessionRestauree,
      );
    } catch (e) {
      if (kDebugMode) {
        logDebug('Rangement des données héritées impossible : ${e.runtimeType}');
      }
    }
  }

  /// Verse le panier composé sans compte dans le panier du compte.
  ///
  /// L'échec est contenu, **et le panier local n'est pas effacé** : voir
  /// `CartController.adoptGuestCart`, qui ne vide le magasin qu'après un
  /// versement réellement abouti.
  Future<void> _reprendrePanierInvite() async {
    try {
      await ref.read(cartControllerProvider.notifier).adoptGuestCart();
    } catch (e) {
      if (kDebugMode) {
        logDebug('Reprise du panier visiteur impossible : ${e.runtimeType}');
      }
    }
  }

  /// Rattache le jeton FCM au compte qui vient d'ouvrir sa session.
  ///
  /// `NotificationService.init()` s'exécute au démarrage, souvent **avant**
  /// toute session : `registerTokenOnServer` sort alors sans rien faire, parce
  /// qu'un jeton appartient à un compte. C'est ici, et nulle part ailleurs, que
  /// l'appel a un sens. La méthode est idempotente (voir son en-tête) : la
  /// rappeler sur une session déjà enregistrée ne produit aucune requête.
  Future<void> _enregistrerJetonPush() async {
    try {
      await ref.read(notificationServiceProvider).registerTokenOnServer();
    } catch (e) {
      if (kDebugMode) {
        logDebug('Enregistrement du jeton FCM impossible : ${e.runtimeType}');
      }
    }
  }

  // ─── Fermeture ────────────────────────────────────────────────────────────

  /// Filet de sécurité pour les sorties de session qui ne passent pas par
  /// `AuthController.signOut()` : jeton révoqué côté serveur, compte supprimé
  /// depuis la console Firebase, changement de compte direct.
  ///
  /// `signOut()` invalide déjà la même liste ; l'invalidation est idempotente,
  /// et la payer deux fois coûte moins cher que de laisser les données d'un
  /// compte à l'écran d'un autre.
  Future<void> _fermeture() async {
    invalidateUserScopedProviders(ref);
    ref.read(notificationServiceProvider).forgetRegisteredToken();
    await _purgerPanierInvite();
  }

  /// Efface le panier composé sans compte quand une session se ferme.
  ///
  /// ## Pourquoi il fallait l'ajouter ici précisément
  ///
  /// `guest_cart_v1` est volontairement **globale** : tout le mode visiteur
  /// repose sur le fait qu'elle survive à la connexion pour être versée
  /// (voir `user_scoped_prefs.dart`). Ce raisonnement est juste, et il ne
  /// couvre qu'un sens.
  ///
  /// À la fermeture, le magasin n'est pas nécessairement vide :
  /// [CartController.adoptGuestCart] conserve délibérément les lignes refusées
  /// par le catalogue, et conserve le panier **entier** sur panne réseau —
  /// deux garanties qu'on veut garder. Ces lignes appartiennent à celui qui
  /// part. Sur un téléphone partagé, le compte suivant se les voyait verser
  /// dans son propre panier serveur à l'ouverture de sa session, et pouvait
  /// les payer.
  ///
  /// L'arbitrage : quelqu'un qui se déconnecte volontairement perd un panier
  /// non versé. Un panier perdu se recompose ; un panier payé par quelqu'un
  /// d'autre ne se défait pas.
  ///
  /// ⚠️ Cette purge n'a lieu QUE sur une fermeture de session — jamais au
  /// démarrage sans session, où `_surSession` sort avant d'appeler
  /// [_fermeture]. Un visiteur qui n'a jamais eu de compte garde son panier.
  Future<void> _purgerPanierInvite() async {
    try {
      final magasin = await ref.read(guestCartStoreProvider.future);
      await magasin.clear();
    } catch (e) {
      if (kDebugMode) {
        logDebug('Purge du panier visiteur impossible : ${e.runtimeType}');
      }
    }
  }
}
