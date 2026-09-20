import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lilia_app/features/auth/application/password_controller.dart';
import 'package:lilia_app/features/auth/application/sign_in_controller.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
import 'package:lilia_app/features/favoris/application/restaurant_favorites_provider.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/user/data/adresse_repository.dart';
import 'package:lilia_app/features/cart/application/draft_orders_provider.dart';
import 'package:lilia_app/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

part 'auth_controller.g.dart';

/// **La session, et rien d'autre.**
///
/// L'état de ce contrôleur répond à une seule question : *qui est connecté ?*
/// Il vaut `AsyncData(user)` quand quelqu'un l'est, `AsyncData(null)` sinon —
/// et c'est le flux Firebase qui l'écrit, jamais une opération.
///
/// ⚠️ **Ne jamais y écrire depuis une méthode d'action.** Cinq méthodes le
/// faisaient (`sigInInUserWithEmailAndPassword`, `createUserWithEmailAndPassword`,
/// `signInWithGoogle`, `updatePassword`, `sendPasswordResetEmail`) : elles
/// posaient `AsyncValue.loading()` pour dire « ça travaille » et
/// `AsyncValue.data(null)` pour dire « c'est fini ». Dans ce contrôleur-là,
/// `data(null)` veut dire **« personne n'est connecté »** : après un simple
/// changement de mot de passe, `edit_profile_page` — qui lit
/// `ref.watch(authControllerProvider).value` — affichait « Utilisateur non
/// trouvé » à un client dont la session était intacte.
///
/// Ces opérations vivent désormais dans [SignInController] et
/// [PasswordController], dont l'état ne raconte que leur propre déroulement.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Stream<AppUser?> build() {
    // Écoute les changements d'état d'authentification de Firebase
    final authStream = ref.watch(authRepositoryProvider).authStateChanges();

    // Écoute le stream de manière sécurisée avec nettoyage onDispose
    final subscription = authStream.listen((user) {
      if (user != null) {
        // L'utilisateur est connecté
        _setupNotifications();
        // Le panier composé avant la connexion est versé dans le panier du
        // compte. C'est ici — sur la transition de session, pas sur un écran —
        // parce que la connexion peut venir de six endroits (mot de passe,
        // Google, Apple, téléphone, inscription, reprise de session) et que
        // chacun oublierait tôt ou tard de le faire. Voir
        // `CartController.adoptGuestCart`.
        _adoptGuestCart();
      }
    });
    ref.onDispose(subscription.cancel);

    return authStream;
  }

  /// Enregistre le jeton FCM maintenant que l'utilisateur est authentifié.
  ///
  /// Ne pas rappeler `init()` : déjà exécuté au démarrage via
  /// `notificationInitializerProvider`.
  ///
  /// ⚠️ L'échec est contenu **volontairement**. Cet appel est déclenché depuis
  /// l'écoute du flux de session, sans `await` : une exception y deviendrait
  /// une erreur asynchrone non capturée. Et surtout, ne pas recevoir de
  /// notifications ne doit jamais empêcher d'ouvrir une session — c'est
  /// exactement le genre de dépendance qui transforme une panne de service
  /// tiers en impossibilité de se connecter.
  Future<void> _setupNotifications() async {
    try {
      await ref.read(notificationServiceProvider).registerTokenOnServer();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Enregistrement du jeton FCM impossible : ${e.runtimeType}');
      }
    }
  }

  /// Reprend le panier composé avant la connexion.
  ///
  /// ⚠️ L'échec est contenu, **et le panier local n'est pas effacé** en cas
  /// d'erreur (cf. `adoptGuestCart`) : ne pas réussir à reprendre un panier ne
  /// doit ni empêcher d'ouvrir une session, ni faire disparaître ce que le
  /// client a composé. L'appel n'est pas attendu, comme celui des
  /// notifications : il est déclenché depuis l'écoute du flux de session.
  Future<void> _adoptGuestCart() async {
    try {
      await ref.read(cartControllerProvider.notifier).adoptGuestCart();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Reprise du panier visiteur impossible : ${e.runtimeType}');
      }
    }
  }

  Future<bool> signOut() async {
    try {
      // Retirer le jeton FCM du serveur avant de fermer la session.
      //
      // ⚠️ L'échec est contenu. Cet appel partage le sort du service de
      // notifications : s'il est indisponible, **la déconnexion doit quand
      // même aboutir**. Sans cette garde, une panne FCM enfermait le client
      // dans une session dont il ne pouvait plus sortir — et la garde de
      // session (`SessionGuard`) ne pouvait pas davantage nettoyer un jeton
      // que le serveur venait de refuser.
      try {
        await ref.read(notificationServiceProvider).removeTokenFromServer();
      } catch (_) {}

      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signOut();

      _invalidateUserScopedProviders();

      return true;
    } on Exception {
      return false;
    }
  }

  /// Supprime définitivement le compte utilisateur (Backend + Firebase Auth).
  ///
  /// Rend `null` en cas de succès, sinon l'échec à montrer. **N'écrit pas dans
  /// `state`** : c'est la session, pas le journal de l'opération. La version
  /// précédente y posait `AsyncValue.error(...)` puis l'écran de profil allait
  /// le relire avec `asError?.error` — un aller-retour qui laissait la session
  /// en erreur, donc `.value` à `null`, bien après la fin de l'opération.
  Future<AuthFailure?> deleteAccount() async {
    try {
      // 1. Supprimer le token FCM sur le serveur
      try {
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.removeTokenFromServer();
      } catch (_) {}

      // 2. Supprimer les données backend.
      //
      // ⚠️ L'échec n'est PLUS avalé. Le backend refuse la suppression en 409
      // quand elle laisserait une transaction sans interlocuteur : commande en
      // cours, boutique possédée, livraison en cours. L'ancien `catch` avalait
      // ce refus puis supprimait quand même le compte Firebase — le client
      // perdait définitivement l'accès à une commande qui était en train
      // d'être livrée, et sa ligne restait ACTIVE en base. Un état qu'aucun
      // écran ne pouvait plus rattraper.
      //
      // La règle : si le serveur dit non, on n'efface rien et on lui rend
      // son message, qui nomme la commande ou la boutique en cause.
      final userRepository = ref.read(userRepositoryProvider);
      await userRepository.deleteAccount();

      // 3. Supprimer le compte Firebase Auth.
      //
      // Le backend l'a normalement déjà fait (`deleteUserSafe`) : cet appel
      // échouera donc souvent en `user-not-found`. C'est le succès, pas une
      // erreur — le compte a bien disparu. On tolère ce seul code ; tout autre
      // échec Firebase reste remonté.
      final authRepository = ref.read(authRepositoryProvider);
      try {
        await authRepository.deleteFirebaseAccount();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found') rethrow;
        if (kDebugMode) {
          debugPrint('Compte Firebase déjà supprimé par le backend — OK.');
        }
      }

      // 4. Invalider tous les providers user-scoped
      _invalidateUserScopedProviders();

      return null;
    } catch (e) {
      // 409 = refus métier motivé (commande en cours, boutique possédée,
      // livraison en cours). Le message du serveur nomme le blocage : le
      // mappeur le laisse passer intact plutôt que de le remplacer par un
      // générique qui n'apprendrait rien. Le compte reste intact des deux côtés.
      return mapAuthError(e);
    }
  }

  /// Vide tout ce qui appartient au compte qui s'en va.
  ///
  /// ⚠️ `restaurantFavoritesProvider` est `keepAlive` : sans invalidation, les
  /// favoris du compte précédent restaient visibles après reconnexion (C10).
  ///
  /// Une seule liste, appelée par la déconnexion **et** par la suppression de
  /// compte. Les deux en portaient chacune une copie de douze lignes : le jour
  /// où l'une gagne un provider et pas l'autre, la fuite ne se voit pas.
  void _invalidateUserScopedProviders() {
    ref.invalidate(cartControllerProvider);
    ref.invalidate(notificationHistoryProvider);
    ref.invalidate(orderRepositoryProvider);
    ref.invalidate(userOrdersProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(restaurantFavoritesProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(referralStatsProvider);
    ref.invalidate(loyaltyTransactionsProvider);
    ref.invalidate(adresseControllerProvider);
    ref.invalidate(adresseRepositoryProvider);
    ref.invalidate(draftOrdersProvider);
  }
}
