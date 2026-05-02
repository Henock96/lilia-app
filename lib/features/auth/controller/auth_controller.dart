import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_error_handler.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
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
    // Ã‰coute les changements d'Ã©tat d'authentification de Firebase
    final authStream = ref.watch(authRepositoryProvider).authStateChanges();

    // Ã‰coute le stream pour dÃ©clencher l'initialisation des notifications
    authStream.listen((user) {
      if (user != null) {
        // L'utilisateur est connectÃ©
        _setupNotifications();
      }
    });

    return authStream;
  }

  Future<void> _setupNotifications() async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.init();
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
        print('Caught error: $e');
        print('Runtime type: ${e.runtimeType}');
      }
      state = AsyncValue.error(
        "Une erreur inconnue est survenue. Veuillez rÃ©essayer.",
        st,
      );
    }
  }

  Future<void> createUserWithEmailAndPassword(String email, String password, String name, String phone, {String? referralCode}) async {
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
        print('Caught error: $e');
        print('Runtime type: ${e.runtimeType}');
      }
      state = AsyncValue.error(
        "Une erreur inconnue est survenue. Veuillez rÃ©essayer.",
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
        // L'utilisateur a annulÃ© la connexion Google
        state = const AsyncValue.data(null);
      } else {
        // Connexion rÃ©ussie
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

      // Invalider les providers pour vider le cache utilisateur
      ref.invalidate(cartControllerProvider);
      ref.invalidate(notificationHistoryProvider);
      ref.invalidate(orderRepositoryProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(userProfileProvider);

      return true;
    } on Exception {
      return false;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      state = const AsyncValue.data(null); // SuccÃ¨s
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
      state = const AsyncValue.data(null); // SuccÃ¨s
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail();
      state = const AsyncValue.data(null); // SuccÃ¨s
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}


