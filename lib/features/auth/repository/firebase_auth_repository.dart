import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../app_user_model.dart';
import '../domain/auth_failure.dart';
import 'package:lilia_app/core/log.dart';

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
          logDebug('Background /users/sync failed: ${e.kind}');
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
      throw kAuthUnknown;
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
      //
      // ⚠️ La suppression est protégée : si elle échoue à son tour (réseau
      // coupé entre-temps), c'est l'échec de synchronisation qu'il faut
      // rapporter au client — pas celui du nettoyage, qu'il ne peut ni
      // comprendre ni corriger.
      try {
        await user.delete();
      } catch (_) {}
      // Le message du serveur est déjà en français et nomme la cause : il
      // traverse intact. L'ancienne version l'enveloppait dans un
      // `Exception('Échec de la sauvegarde… : …')`, que le contrôleur
      // remplaçait ensuite par « Une erreur inconnue est survenue ».
      throw mapAuthError(e);
    }
  }

  /// Connexion Google.
  ///
  /// [referralCode] n'est transmis qu'à la **création** du compte : le backend
  /// ignore le code sur un compte existant, ce qui rend le changement de
  /// parrain impossible. Le paramètre existait pour l'inscription par e-mail
  /// mais pas ici — un filleul arrivé par Google n'était donc jamais rattaché
  /// à son parrain, silencieusement.
  ///
  /// ⚠️ **Le type de retour n'est pas nullable, et c'est le correctif.** Il
  /// l'était, et le contrôleur en déduisait une annulation : `if (googleUser ==
  /// null) → l'utilisateur a annulé`. Or `GoogleSignIn.authenticate()` rend un
  /// `Future<GoogleSignInAccount>` **non nullable** et **lève**
  /// `GoogleSignInException(code: canceled)` — la branche était donc morte, et
  /// l'annulation partait dans le `catch` générique, qui affichait
  /// `GoogleSignInException(code GoogleSignInExceptionCode.canceled, …)` au
  /// client. Rendre `AppUser` non nullable rend cette confusion
  /// inexprimable : une annulation est un échec typé, pas une absence.
  Future<AppUser> signInWithGoogle({String? referralCode}) async {
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
      throw kAuthUnknown;
    }

    // Étape 6: Créer les credentials Firebase (seul l'idToken est nécessaire)
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    // Étape 7: Se connecter à Firebase avec les credentials
    final userCred = await _firebaseAuth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) {
      throw kAuthUnknown;
    }

    final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

    // Étape 8: Synchroniser avec le backend
    // Note: Le backend utilise UPSERT donc gère inscription ET connexion
    try {
      if (kDebugMode) {
        logDebug('Synchronizing Google user with backend...');
      }

      await _api.postJson(
        '/users/sync',
        body: {
          'firebaseUid': user.uid,
          'email': user.email,
          'nom': user.displayName,
          'telephone': user.phoneNumber,
          // Uniquement sur une inscription : sur une connexion, le serveur
          // l'ignorerait de toute façon, et l'envoyer laisserait croire le
          // contraire à la lecture.
          if (isNewUser && referralCode != null && referralCode.isNotEmpty)
            'referralCode': referralCode,
        },
      );

      if (kDebugMode) {
        logDebug('User successfully synchronized with backend');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        logDebug('Backend sync failed: ${e.kind} ${e.statusCode}');
      }
      // Supprimer l'utilisateur Firebase UNIQUEMENT s'il s'agit d'une nouvelle
      // inscription, pour éviter de détruire le compte d'un utilisateur
      // existant (C-AUTH-1).
      if (isNewUser) {
        try {
          await user.delete();
        } catch (_) {}
      }
      // Une panne réseau ou un serveur muet empêchent de savoir si le compte
      // est utilisable : on le dit, même à un compte existant.
      if (e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout) {
        throw mapAuthError(e);
      }
      // Un compte **existant** dont la synchronisation a échoué pour une autre
      // raison reste parfaitement connecté : le serveur ne fait ici que
      // rafraîchir `lastLogin`. Bloquer la session serait une punition sans
      // rapport avec la panne.
      if (isNewUser) {
        throw mapAuthError(e);
      }
    }
    // `user` est non nul ici : le cas contraire a déjà levé plus haut.
    return AppUser.fromFirebaseUser(user)!;
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

  /// Supprime le compte utilisateur Firebase et déconnecte les services associés.
  Future<void> deleteFirebaseAccount() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  /// Le dépôt ne traduit plus : il laisse remonter la `FirebaseAuthException`
  /// telle quelle. `PasswordController` la passe à `mapAuthError`, seul point
  /// de traduction de l'application. La version précédente enveloppait
  /// `requires-recent-login` dans un `Exception('…')` — que l'écran affichait
  /// préfixé de « Exception: » — et laissait **tous les autres codes** filer
  /// bruts jusqu'au client, `[firebase_auth/weak-password] …` compris.
  Future<void> updatePassword(String newPassword) async {
    await _firebaseAuth.currentUser?.updatePassword(newPassword);
  }

  Future<void> sendPasswordResetEmailWithEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendPasswordResetEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw kAuthSessionExpired;
    }
    await _firebaseAuth.sendPasswordResetEmail(email: user.email!);
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
