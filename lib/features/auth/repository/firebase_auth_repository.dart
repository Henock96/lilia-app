import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_user_model.dart';

part 'firebase_auth_repository.g.dart';

class FirebaseAuthenticationRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final http.Client _client;

  FirebaseAuthenticationRepository(
    this._firebaseAuth,
    this._googleSignIn,
    this._client,
  );

  AppUser? get currentUser => _convertUser(_firebaseAuth.currentUser);

  // convertit le FirebaseUser nullable en notre AppUser
  AppUser? _convertUser(User? user) =>
      user == null ? null : AppUser.fromFirebaseUser(user);

  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_convertUser);
  }

  // RÃ©cupÃ¨re le jeton ID Firebase de l'utilisateur actuellement connectÃ©.
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
        final idToken = await user.getIdToken();
        await _client.post(
          Uri.parse('${AppConstants.baseUrl}/users/sync'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
          body: jsonEncode({'firebaseUid': user.uid, 'email': user.email}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
  String? referralCode,
  }) async {
    // Ã‰tape 1: CrÃ©er l'utilisateur dans Firebase Auth
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw Exception("La crÃ©ation de l'utilisateur a Ã©chouÃ©.");
    }
    // Ã‰tape 3: Sauvegarder les informations dans notre backend
    final idToken = await user.getIdToken();
    final url = Uri.parse('${AppConstants.baseUrl}/users/sync');

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'firebaseUid': user.uid,
        'email': email,
        'nom': name,
        'telephone': phone,
      if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      // Si le backend Ã©choue, nous devrions peut-Ãªtre supprimer l'utilisateur de Firebase
      // pour Ã©viter un Ã©tat incohÃ©rent. Pour l'instant, nous lanÃ§ons une exception.
      await user.delete();
      throw Exception(
        'Ã‰chec de la sauvegarde des informations utilisateur sur le backend: ${response.body}',
      );
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    // Ã‰tape 1: Initialiser GoogleSignIn si nÃ©cessaire
    await _googleSignIn.initialize();

    // Ã‰tape 2: DÃ©connecter tout utilisateur Google prÃ©cÃ©dent
    // pour s'assurer d'avoir un Ã©tat propre
    await _googleSignIn.disconnect();

    // Ã‰tape 3: Authentifier l'utilisateur avec Google Sign In
    // Utilise authenticate() qui retourne un GoogleSignInUser
    final googleUser = await _googleSignIn.authenticate();

    // Ã‰tape 4: Obtenir le client d'autorisation pour Firebase

    // Ã‰tape 5: Obtenir l'ID token depuis les headers du client
    //final headers = await authClient.credentials.headers;
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception("Impossible d'obtenir le token d'authentification");
    }

    // Ã‰tape 6: CrÃ©er les credentials Firebase (seul l'idToken est nÃ©cessaire)
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    // Ã‰tape 7: Se connecter Ã  Firebase avec les credentials
    final userCred = await _firebaseAuth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) {
      throw Exception("La connexion Google a Ã©chouÃ©.");
    }

    // Ã‰tape 8: Synchroniser avec le backend
    // Note: Le backend utilise UPSERT donc gÃ¨re inscription ET connexion
    try {
      final firebaseIdToken = await user.getIdToken();
      final url = Uri.parse('${AppConstants.baseUrl}/users/sync');

      if (kDebugMode) {
        print('ðŸ”„ Synchronizing user with backend...');
        print('ðŸ“§ Email: ${user.email}');
        print('ðŸ†” Firebase UID: ${user.uid}');
      }

      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $firebaseIdToken',
            },
            body: jsonEncode({
              'firebaseUid': user.uid,
              'email': user.email,
              'nom': user.displayName,
              'telephone': user.phoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('ðŸ“¡ Backend response status: ${response.statusCode}');
        print('ðŸ“¡ Backend response body: ${response.body}');
      }

      // Accepter 200 (utilisateur existant/mis Ã  jour) et 201 (nouvel utilisateur crÃ©Ã©)
      if (response.statusCode != 201 && response.statusCode != 200) {
        if (kDebugMode) {
          print('âŒ Backend sync failed with status ${response.statusCode}');
        }
        // Supprimer l'utilisateur Firebase seulement si le backend Ã©choue
        await user.delete();
        throw Exception(
          'Ã‰chec de la synchronisation avec le backend (${response.statusCode}): ${response.body}',
        );
      }

      if (kDebugMode) {
        print('âœ… User successfully synchronized with backend');
      }
    } on http.ClientException catch (e) {
      // Erreur rÃ©seau
      if (kDebugMode) {
        print('âŒ Network error during backend sync: $e');
      }
      await user.delete();
      throw Exception('Erreur rÃ©seau: Impossible de se connecter au serveur');
    } on TimeoutException catch (e) {
      // Timeout
      if (kDebugMode) {
        print('âŒ Timeout during backend sync: $e');
      }
      await user.delete();
      throw Exception('Le serveur ne rÃ©pond pas. Veuillez rÃ©essayer.');
    } catch (e) {
      // Autre erreur
      if (kDebugMode) {
        print('âŒ Unexpected error during backend sync: $e');
      }
      await user.delete();
      rethrow;
    }
    return AppUser.fromFirebaseUser(user);
  }

  Future<bool> signOut() async {
    try {
      // DÃ©connecter de Google Sign In (utilise disconnect pour nettoyer complÃ¨tement)
      await _googleSignIn.disconnect();
      // DÃ©connecter de Firebase Auth
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
      // GÃ©rer les erreurs, par exemple si l'utilisateur doit se reconnecter
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'Cette opÃ©ration est sensible et nÃ©cessite une authentification rÃ©cente. Veuillez vous dÃ©connecter et vous reconnecter avant de rÃ©essayer.',
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
          "Aucun utilisateur connectÃ© ou l'email n'est pas disponible.",
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
http.Client httpClient(Ref ref) {
  return http.Client();
}

@Riverpod(keepAlive: true)
FirebaseAuthenticationRepository authRepository(Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final google = ref.watch(googleSignInProvider);
  final client = ref.watch(httpClientProvider);
  return FirebaseAuthenticationRepository(auth, google, client);
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


