import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_error_handler.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
import 'package:lilia_app/features/favoris/application/restaurant_favorites_provider.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:lilia_app/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

part 'auth_controller.g.dart';

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
      }
    });
    ref.onDispose(subscription.cancel);

    return authStream;
  }

  Future<void> _setupNotifications() async {
    // Ne pas rappeler init() - déjà exécuté au démarrage via notificationInitializerProvider.
    // registerTokenOnServer() récupère le token FCM si besoin et l'enregistre maintenant
    // que l'utilisateur est authentifié.
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.registerTokenOnServer();
  }

  Future<void> sigInInUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      AnalyticsService.logLogin(method: 'email');
    } on FirebaseAuthException catch (e, st) {
      final error = FirebaseAuthErrorHandler.handleException(e);
      final errorMessage = FirebaseAuthErrorHandler.getErrorMessage(error);
      state = AsyncValue.error(errorMessage, st);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Email sign-in failed: ${e.runtimeType}');
      }
      state = AsyncValue.error(
        "Une erreur inconnue est survenue. Veuillez réessayer.",
        st,
      );
    }
  }

  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phone, {
    String? referralCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(authRepositoryProvider)
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
            name: name,
            phone: phone,
            referralCode: referralCode,
          );
      AnalyticsService.logSignUp(method: 'email');
    } on FirebaseAuthException catch (e, st) {
      final error = FirebaseAuthErrorHandler.handleException(e);
      final errorMessage = FirebaseAuthErrorHandler.getErrorMessage(error);
      state = AsyncValue.error(errorMessage, st);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Email sign-up failed: ${e.runtimeType}');
      }
      state = AsyncValue.error(
        "Une erreur inconnue est survenue. Veuillez réessayer.",
        st,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final googleUser = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle();
      if (googleUser == null) {
        // L'utilisateur a annulé la connexion Google
        state = const AsyncValue.data(null);
      } else {
        // Connexion réussie
        AnalyticsService.logLogin(method: 'google');
        state = AsyncValue.data(googleUser);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> signOut() async {
    try {
      // Remove FCM token from server before signing out
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.removeTokenFromServer();

      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signOut();

      // Invalider TOUS les providers user-scoped pour vider le cache (C10).
      // ⚠️ restaurantFavoritesProvider est keepAlive : sans invalidation, les
      // favoris du compte précédent restaient visibles après reconnexion.
      ref.invalidate(cartControllerProvider);
      ref.invalidate(notificationHistoryProvider);
      ref.invalidate(orderRepositoryProvider);
      ref.invalidate(userOrdersProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(restaurantFavoritesProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(referralStatsProvider);
      ref.invalidate(loyaltyTransactionsProvider);

      return true;
    } on Exception {
      return false;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      state = const AsyncValue.data(null); // Succès
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmailWithEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmailWithEmail(email);
      state = const AsyncValue.data(null); // Succès
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail();
      state = const AsyncValue.data(null); // Succès
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Supprime définitivement le compte utilisateur (Backend + Firebase Auth).
  Future<bool> deleteAccount() async {
    state = const AsyncValue.loading();
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
      ref.invalidate(cartControllerProvider);
      ref.invalidate(notificationHistoryProvider);
      ref.invalidate(orderRepositoryProvider);
      ref.invalidate(userOrdersProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(restaurantFavoritesProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(referralStatsProvider);
      ref.invalidate(loyaltyTransactionsProvider);

      state = const AsyncValue.data(null);
      return true;
    } on ApiException catch (e, st) {
      // 409 = refus métier motivé (commande en cours, boutique possédée,
      // livraison en cours). Le message du serveur nomme le blocage : on
      // l'affiche tel quel plutôt que de le remplacer par un générique qui
      // n'apprendrait rien. Le compte reste intact des deux côtés.
      state = AsyncValue.error(e.message, st);
      return false;
    } on FirebaseAuthException catch (e, st) {
      if (e.code == 'requires-recent-login') {
        state = AsyncValue.error(
          'Cette opération est sensible. Veuillez vous reconnecter avant de supprimer votre compte.',
          st,
        );
      } else {
        state = AsyncValue.error(
          'Impossible de supprimer le compte. Veuillez réessayer.',
          st,
        );
      }
      return false;
    } catch (e, st) {
      state = AsyncValue.error(
        'Une erreur est survenue lors de la suppression du compte.',
        st,
      );
      return false;
    }
  }
}
