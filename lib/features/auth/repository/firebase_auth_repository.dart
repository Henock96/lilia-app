import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_user_model.dart';

part 'firebase_auth_repository.g.dart';

class FirebaseAuthenticationRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final http.Client _client;

  FirebaseAuthenticationRepository(this._firebaseAuth, this._googleSignIn, this._client);

  AppUser? get currentUser => _convertUser(_firebaseAuth.currentUser);

  // convertit le FirebaseUser nullable en notre AppUser
  AppUser? _convertUser(User? user) => user == null ? null : AppUser.fromFirebaseUser(user);

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
      throw Exception('Échec de la sauvegarde des informations utilisateur sur le backend: ${response.body}');
    }
  }

  Future<void> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
    }
  }

  Future<bool> signOut() async {
    try{
      await _googleSignIn.signOut();
      _firebaseAuth.signOut();
      return true;
    }on Exception catch(e){
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
http.Client httpClient(HttpClientRef ref) {
  return http.Client();
}

@Riverpod(keepAlive: true)
FirebaseAuthenticationRepository authRepository(AuthRepositoryRef ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final googleSignIn = ref.watch(googleSignInProvider);
  final client = ref.watch(httpClientProvider);
  return FirebaseAuthenticationRepository(auth, googleSignIn, client);
}

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) {
  return FirebaseAuth.instance;
}

@Riverpod(keepAlive: true)
GoogleSignIn googleSignIn(GoogleSignInRef ref) {
  return GoogleSignIn();
}

@Riverpod(keepAlive: true)
Stream<AppUser?> authStateChange(AuthStateChangeRef ref) {
  final auth = ref.watch(authRepositoryProvider);
  return auth.authStateChanges();
}

@Riverpod(keepAlive: true)
Stream<String?> firebaseIdToken(FirebaseIdTokenRef ref) {
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
