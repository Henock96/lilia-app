import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lilia_app/features/auth/application/session_effects.dart';
import 'package:lilia_app/features/auth/application/user_scoped_providers.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/core/log.dart';

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
///
/// ## Ce contrôleur ne porte plus aucun effet de session
///
/// `build()` posait une écoute manuelle sur `authStateChanges()` pour y
/// déclencher la reprise du panier visiteur et l'enregistrement du jeton FCM.
/// Deux défauts, tous deux corrigés ici :
///
/// 1. **Ces effets ne s'exécutaient jamais.** Ce provider n'est observé par
///    aucun écran au démarrage (le seul `ref.watch` est dans
///    `edit_profile_page.dart`), et Riverpod ne construit pas un provider que
///    personne ne lit. Ils vivent désormais dans [SessionEffects], observé par
///    `MyApp`.
/// 2. **Double abonnement.** `build()` s'abonnait à la main *et* rendait le
///    même `Stream`, que Riverpod souscrit à son tour — deux souscriptions
///    pour une source.
///
/// Il ne reste ici que la session et les opérations qui la ferment.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Stream<AppUser?> build() =>
      ref.watch(authRepositoryProvider).authStateChanges();

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
          logDebug('Compte Firebase déjà supprimé par le backend — OK.');
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
  /// La liste elle-même vit dans `user_scoped_providers.dart` : elle a trois
  /// appelants (déconnexion, suppression de compte, fermeture de session
  /// observée par [SessionEffects]), et trois copies d'une liste qu'on
  /// complète à chaque nouveau provider finiraient par diverger.
  void _invalidateUserScopedProviders() => invalidateUserScopedProviders(ref);
}
