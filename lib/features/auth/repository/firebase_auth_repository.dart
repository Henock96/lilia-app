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

    // Étape 8: Synchroniser avec le backend
    return _synchroniserConnexionFournisseur(
      userCred,
      referralCode: referralCode,
    );
  }

  /// Connexion Apple — iOS uniquement (le bouton n'existe pas ailleurs).
  ///
  /// ## Pourquoi `signInWithProvider` et pas `OAuthProvider('apple.com')`
  ///
  /// Sur iOS, `firebase_auth` ouvre lui-même la feuille système Apple
  /// (`ASAuthorizationController`), **génère le nonce**, envoie son SHA-256 à
  /// Apple et le nonce brut à Firebase : c'est la protection anti-rejeu du
  /// jeton Apple, et elle n'a pas à être recodée ici. Il transmet aussi le nom
  /// complet à Firebase, qui en fait le `displayName` du compte.
  ///
  /// Le montage « à la main » qu'on trouve partout —
  /// `OAuthProvider('apple.com').credential(idToken:, accessToken:)` sans
  /// `rawNonce` — est refusé par Firebase, et perd le nom.
  ///
  /// ## Ce qu'Apple ne rend qu'une fois
  ///
  /// Le nom (et l'adresse, dans la feuille) n'est fourni **qu'à la première
  /// autorisation**. Aux connexions suivantes il est absent : c'est Firebase
  /// qui le garde, dans `displayName`. Rien ici ne suppose donc qu'il existe —
  /// le backend a son propre repli (préfixe de l'adresse).
  ///
  /// L'adresse peut être un relais `…@privaterelay.appleid.com` : c'est une
  /// adresse valide, conservée telle quelle. Le backend la lit dans le jeton
  /// Firebase, jamais dans ce que ce dépôt lui envoie.
  ///
  /// ## Adresse déjà inscrite par e-mail ou Google
  ///
  /// Le projet impose « un compte par adresse » : Firebase lève alors
  /// `account-exists-with-different-credential` et **ne crée rien**. L'échec
  /// remonte tel quel ; `mapAuthError` invite le client à utiliser sa méthode
  /// d'origine. Aucune liaison automatique : une adresse identique ne prouve
  /// pas que c'est la même personne.
  ///
  // TODO(apple-linking): proposer « Lier mon identifiant Apple » depuis le
  // profil, APRÈS connexion par la méthode d'origine :
  // `currentUser.linkWithProvider(AppleAuthProvider())` (flux natif, nonce
  // géré par Firebase). Ne pas réutiliser `FirebaseAuthException.credential`
  // de l'erreur : sur iOS c'est un identifiant natif opaque, et la protection
  // contre l'énumération des e-mails (activée) peut en retirer l'adresse.
  Future<AppUser> signInWithApple({String? referralCode}) async {
    final userCred =
        await _firebaseAuth.signInWithProvider(_appleProvider(profil: true));

    // Le nom Apple vient d'être posé sur le compte Firebase. Rien ne garantit
    // que le jeton déjà en cache le porte : sans rafraîchissement, le serveur
    // pourrait créer le client sous le préfixe aléatoire de son adresse relais
    // (`x7k2p9…`) alors que le vrai nom est connu. Uniquement à la création, et
    // jamais bloquant : le repli du serveur reste acceptable.
    final user = userCred.user;
    final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;
    if (user != null &&
        isNewUser &&
        (user.displayName?.trim().isNotEmpty ?? false)) {
      try {
        await user.getIdToken(true);
      } catch (_) {}
    }

    return _synchroniserConnexionFournisseur(
      userCred,
      referralCode: referralCode,
    );
  }

  /// Fournisseur Apple. [profil] demande le nom et l'adresse — utile à la
  /// connexion, inutile à la ré-authentification qui précède une suppression.
  static AppleAuthProvider _appleProvider({required bool profil}) {
    final provider = AppleAuthProvider();
    if (profil) {
      provider
        ..addScope('email')
        ..addScope('name');
    }
    return provider;
  }

  /// Ce qui suit une connexion Google **ou** Apple : `/users/sync`, avec la
  /// même politique d'échec pour les deux.
  ///
  /// Le corps envoyé n'est qu'indicatif : le serveur prend l'identité
  /// (`uid`, `email`, `name`) **dans le jeton Firebase vérifié** et ne lit ici
  /// que `telephone` et `referralCode`.
  Future<AppUser> _synchroniserConnexionFournisseur(
    UserCredential userCred, {
    String? referralCode,
  }) async {
    final user = userCred.user;
    if (user == null) {
      throw kAuthUnknown;
    }

    final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

    // Note: Le backend utilise UPSERT donc gère inscription ET connexion
    try {
      if (kDebugMode) {
        logDebug('Synchronizing provider user with backend...');
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

  /// Révoque l'autorisation Apple du compte connecté, s'il en a une.
  ///
  /// **Exigence App Store** (5.1.1(v)) : supprimer un compte ouvert avec Apple
  /// doit révoquer ses jetons auprès d'Apple. La suppression Firebase faite par
  /// le backend (`deleteUserSafe`) ne le fait pas.
  ///
  /// La révocation exige un `authorizationCode` **frais** (valable cinq
  /// minutes) : on le demande par une ré-authentification Apple, qui présente
  /// la feuille système au client. S'il l'annule, ou si elle échoue, l'échec
  /// remonte et **rien n'est supprimé** — c'est à l'appelant de s'arrêter.
  ///
  /// Sans effet pour un compte e-mail ou Google.
  Future<void> revokeAppleSignInIfLinked() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    final lieAApple = user.providerData
        .any((p) => p.providerId == AppleAuthProvider.PROVIDER_ID);
    if (!lieAApple) return;

    try {
      final cred = await user.reauthenticateWithProvider(
        _appleProvider(profil: false),
      );
      final code = cred.additionalUserInfo?.authorizationCode;
      if (code == null || code.isEmpty) {
        throw kAuthAppleVerificationFailed;
      }
      await _firebaseAuth.revokeTokenWithAuthorizationCode(code);
    } on FirebaseAuthException catch (e) {
      // Dans ce contexte, la traduction ordinaire tromperait : un
      // `invalid-credential` y deviendrait « Adresse e-mail ou mot de passe
      // incorrect », à un client qui n'a saisi ni l'un ni l'autre. On ne garde
      // que les causes qui disent au client quoi faire ; tout le reste devient
      // « la vérification a échoué, rien n'a été supprimé ».
      const parlants = {
        'canceled',
        'web-context-canceled',
        'network-request-failed',
        'too-many-requests',
        'user-mismatch',
      };
      if (parlants.contains(e.code)) rethrow;
      throw kAuthAppleVerificationFailed;
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
