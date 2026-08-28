import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../app_user_model.dart';

part 'firebase_auth_repository.g.dart';

class FirebaseAuthenticationRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final ApiClient _api;

  FirebaseAuthenticationRepository(
    this._firebaseAuth,
    this._googleSignIn,
    this._api,
  );

  AppUser? get currentUser => _convertUser(_firebaseAuth.currentUser);

  // convertit le FirebaseUser nullable en notre AppUser
  AppUser? _convertUser(User? user) =>
      user == null ? null : AppUser.fromFirebaseUser(user);

  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_convertUser);
  }

  // Récupère le jeton ID Firebase de l'utilisateur actuellement connecté.
  Future<String?> getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user != null) {
      try {
        await _api.postJson(
          '/users/sync',
          body: {'firebaseUid': user.uid, 'email': user.email},
        );
      } on ApiException catch (e) {
        // Sync best-effort (met à jour lastLogin) : non bloquant pour la
        // connexion, mais on trace l'échec en debug au lieu de l'avaler (C19).
        if (kDebugMode) {
          debugPrint('Background /users/sync failed: ${e.kind}');
        }
      }
    }
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? referralCode,
  }) async {
    // Étape 1: Créer l'utilisateur dans Firebase Auth
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw Exception("La création de l'utilisateur a échoué.");
    }
    // Étape 3: Sauvegarder les informations dans notre backend
    try {
      await _api.postJson(
        '/users/sync',
        body: {
          'firebaseUid': user.uid,
          'email': email,
          'nom': name,
          'telephone': phone,
          if (referralCode != null && referralCode.isNotEmpty)
            'referralCode': referralCode,
        },
      );
    } on ApiException catch (e) {
      // Si le backend échoue, on supprime l'utilisateur Firebase pour éviter
      // un état incohérent.
      await user.delete();
      throw Exception(
        'Échec de la sauvegarde des informations utilisateur sur le backend: ${e.message}',
      );
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    // Étape 1: Initialiser GoogleSignIn si nécessaire
    await _googleSignIn.initialize();

    // Étape 2: Déconnecter tout utilisateur Google précédent
    // pour s'assurer d'avoir un état propre
    await _googleSignIn.disconnect();

    // Étape 3: Authentifier l'utilisateur avec Google Sign In
    // Utilise authenticate() qui retourne un GoogleSignInUser
    final googleUser = await _googleSignIn.authenticate();

    // Étape 4: Obtenir le client d'autorisation pour Firebase

    // Étape 5: Obtenir l'ID token depuis les headers du client
    //final headers = await authClient.credentials.headers;
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception("Impossible d'obtenir le token d'authentification");
    }

    // Étape 6: Créer les credentials Firebase (seul l'idToken est nécessaire)
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    // Étape 7: Se connecter à Firebase avec les credentials
    final userCred = await _firebaseAuth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) {
      throw Exception("La connexion Google a échoué.");
    }

    // Étape 8: Synchroniser avec le backend
    // Note: Le backend utilise UPSERT donc gère inscription ET connexion
    try {
      if (kDebugMode) {
        debugPrint('Synchronizing Google user with backend...');
      }

      await _api.postJson(
        '/users/sync',
        body: {
          'firebaseUid': user.uid,
          'email': user.email,
          'nom': user.displayName,
          'telephone': user.phoneNumber,
        },
      );

      if (kDebugMode) {
        debugPrint('User successfully synchronized with backend');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('Backend sync failed: ${e.kind} ${e.statusCode}');
      }
      // Supprimer l'utilisateur Firebase si le backend échoue (état cohérent).
      await user.delete();
      if (e.kind == ApiErrorKind.network) {
        throw Exception('Erreur réseau: Impossible de se connecter au serveur');
      }
      if (e.kind == ApiErrorKind.timeout) {
        throw Exception('Le serveur ne répond pas. Veuillez réessayer.');
      }
      throw Exception(
        'Échec de la synchronisation avec le backend (${e.statusCode}).',
      );
    }
    return AppUser.fromFirebaseUser(user);
  }

  Future<bool> signOut() async {
    try {
      // Déconnecter de Google Sign In (utilise disconnect pour nettoyer complètement)
      await _googleSignIn.disconnect();
      // Déconnecter de Firebase Auth
      await _firebaseAuth.signOut();
      return true;
    } on Exception {
      return false;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _firebaseAuth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      // Gérer les erreurs, par exemple si l'utilisateur doit se reconnecter
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'Cette opération est sensible et nécessite une authentification récente. Veuillez vous déconnecter et vous reconnecter avant de réessayer.',
        );
      }
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmailWithEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && user.email != null) {
        await _firebaseAuth.sendPasswordResetEmail(email: user.email!);
      } else {
        throw Exception(
          "Aucun utilisateur connecté ou l'email n'est pas disponible.",
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
FirebaseAuthenticationRepository authRepository(Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final google = ref.watch(googleSignInProvider);
  return FirebaseAuthenticationRepository(
    auth,
    google,
    ref.watch(apiClientProvider),
  );
}

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) {
  return FirebaseAuth.instance;
}

@Riverpod(keepAlive: true)
GoogleSignIn googleSignIn(Ref ref) {
  return GoogleSignIn.instance;
}

@Riverpod(keepAlive: true)
Stream<AppUser?> authStateChange(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  return auth.authStateChanges();
}

@Riverpod(keepAlive: true)
Stream<String?> firebaseIdToken(Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.idTokenChanges().asyncMap((user) async {
    // Si l'utilisateur est null, le jeton est null
    if (user == null) {
      return null;
    }
    // Sinon, obtenez le jeton ID
    return await user.getIdToken();
  });
}
