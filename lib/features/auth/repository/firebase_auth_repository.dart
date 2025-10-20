import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
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

  // Récupère le jeton ID Firebase de l'utilisateur actuellement connecté.
  Future<String?> getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
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
    final idToken = await user.getIdToken();
    final url = Uri.parse('https://lilia-backend.onrender.com/auth/register');

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
      }),
    );

    if (response.statusCode != 201) {
      // Si le backend échoue, nous devrions peut-être supprimer l'utilisateur de Firebase
      // pour éviter un état incohérent. Pour l'instant, nous lançons une exception.
      await user.delete();
      throw Exception(
        'Échec de la sauvegarde des informations utilisateur sur le backend: ${response.body}',
      );
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    // Étape 1: Initialiser GoogleSignIn si nécessaire
    await _googleSignIn.initialize();

    // Étape 2: Authentifier l'utilisateur avec Google Sign In
    final googleUser = await _googleSignIn.authenticate();

    if (googleUser == null) {
      // L'utilisateur a annulé la connexion
      return null;
    }

    // Étape 3: Obtenir l'ID token pour Firebase
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw Exception("Impossible d'obtenir le token d'authentification");
    }

    // Étape 4: Créer les credentials Firebase (seul l'idToken est nécessaire)
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Étape 5: Se connecter à Firebase avec les credentials
    final userCred = await _firebaseAuth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) {
      throw Exception("La connexion Google a échoué.");
    }
    // Après une connexion réussie, vous pouvez envoyer les informations à votre backend si nécessaire.
    final idToken = await user.getIdToken();
    final url = Uri.parse('https://lilia-backend.onrender.com/auth/register');
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'firebaseUid': user.uid,
        'email': user.email,
        'nom': user.displayName,
        'telephone': user.phoneNumber,
      }),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      await user.delete();
      throw Exception(
        'Échec de la sauvegarde des informations utilisateur sur le backend: ${response.body}',
      );
    }
    return AppUser.fromFirebaseUser(user);
  }

  Future<bool> signOut() async {
    try {
      await _googleSignIn.signOut();
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
