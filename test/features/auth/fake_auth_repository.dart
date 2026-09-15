import 'dart:async';

import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

/// Double de test du dépôt d'authentification.
///
/// `implements` et non `extends` : le vrai dépôt exige un `FirebaseAuth`, un
/// `GoogleSignIn` et un `ApiClient` dans son constructeur, or `FirebaseAuth`
/// n'est pas constructible sans `Firebase.initializeApp()`. Passer par
/// l'interface laisse tourner le **vrai** contrôleur — c'est lui qu'on teste.
class FakeAuthRepository implements FirebaseAuthenticationRepository {
  FakeAuthRepository({AppUser? user}) : _user = user;

  AppUser? _user;
  final _sessions = StreamController<AppUser?>.broadcast();

  /// Erreur à lever au prochain appel, par opération.
  Object? googleError;
  Object? signInError;
  Object? signUpError;
  Object? passwordError;

  /// Retient l'opération tant qu'elle n'est pas complétée. Sert à observer
  /// l'état « en cours » depuis un test de widget : sans elle, l'appel se
  /// résout avant même le premier `pump` et l'indicateur n'est jamais visible.
  Completer<void>? porte;

  /// Ce que le dépôt a réellement reçu — sert à vérifier qu'un code de
  /// parrainage suit bien le chemin Google.
  String? dernierReferralCode;
  int appelsGoogle = 0;
  int appelsSignUp = 0;
  int appelsSignOut = 0;

  /// Simule ce que fait Firebase : la session bascule.
  void emitSession(AppUser? user) {
    _user = user;
    _sessions.add(user);
  }

  Future<void> dispose() => _sessions.close();

  @override
  AppUser? get currentUser => _user;

  /// Comme Firebase : chaque abonné reçoit d'abord l'état courant, puis les
  /// bascules. `Stream.multi` est diffusé (`isBroadcast`), ce qui compte :
  /// `AuthController.build()` s'y abonne **deux fois** — une pour le retour du
  /// notifier, une pour l'enregistrement du jeton FCM.
  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.multi((controller) {
        controller.add(_user);
        controller.addStream(_sessions.stream);
      });

  @override
  Future<String?> getIdToken() async => _user == null ? null : 'jeton';

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    emitSession(AppUser(uid: 'uid-$email', email: email));
  }

  @override
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? referralCode,
  }) async {
    appelsSignUp++;
    dernierReferralCode = referralCode;
    if (porte != null) await porte!.future;
    // Fidèle au vrai flux : Firebase connecte l'utilisateur **avant** l'appel
    // à `/users/sync`. C'est cette émission précoce qui déclenchait la
    // redirection vers l'accueil et rendait l'erreur de synchronisation
    // invisible (B-02).
    emitSession(AppUser(uid: 'uid-$email', email: email));
    if (signUpError != null) {
      // Rollback du vrai dépôt : le compte Firebase est supprimé.
      emitSession(null);
      throw signUpError!;
    }
  }

  @override
  Future<AppUser> signInWithGoogle({String? referralCode}) async {
    appelsGoogle++;
    dernierReferralCode = referralCode;
    if (porte != null) await porte!.future;
    if (googleError != null) throw googleError!;
    const user = AppUser(uid: 'uid-google', email: 'google@lilia.cg');
    emitSession(user);
    return user;
  }

  @override
  Future<bool> signOut() async {
    appelsSignOut++;
    emitSession(null);
    return true;
  }

  @override
  Future<void> deleteFirebaseAccount() async => emitSession(null);

  @override
  Future<void> updatePassword(String newPassword) async {
    if (passwordError != null) throw passwordError!;
  }

  @override
  Future<void> sendPasswordResetEmailWithEmail(String email) async {
    if (passwordError != null) throw passwordError!;
  }

  @override
  Future<void> sendPasswordResetEmail() async {
    if (passwordError != null) throw passwordError!;
  }
}
