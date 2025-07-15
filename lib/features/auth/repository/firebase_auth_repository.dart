import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_user_model.dart';

part 'firebase_auth_repository.g.dart';

class FirebaseAuthenticationRepository {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthenticationRepository(this._firebaseAuth);

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
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    return _firebaseAuth.signOut();
  }
}

@Riverpod(keepAlive: true)
FirebaseAuthenticationRepository authRepository(AuthRepositoryRef ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseAuthenticationRepository(auth);
}
@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) {
  return FirebaseAuth.instance;
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