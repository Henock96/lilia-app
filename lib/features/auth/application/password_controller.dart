import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth_failure.dart';
import '../repository/firebase_auth_repository.dart';

part 'password_controller.g.dart';

/// Changement et réinitialisation du mot de passe.
///
/// ## Pourquoi ce contrôleur existe
///
/// Ces trois opérations vivaient dans `AuthController`, dont l'état porte la
/// **session**. Elles y écrivaient `AsyncValue.data(null)` pour dire « c'est
/// terminé » — or dans ce contrôleur-là, `data(null)` veut dire **« personne
/// n'est connecté »**. Le parcours Profil → « Mot de passe » → changer →
/// retour → « Modifier le profil » affichait donc « Utilisateur non trouvé »
/// jusqu'au redémarrage de l'application (B-08).
///
/// ## Pourquoi il rend l'échec au lieu de l'annoncer
///
/// Contrairement à l'inscription, aucune redirection ne démonte l'écran
/// pendant l'opération : l'appelant est toujours là pour montrer le message,
/// au bon endroit et au bon moment. L'[AuthFailureAnnouncer] est réservé aux
/// échecs qui survivent à leur écran.
///
/// `null` signifie succès.
@riverpod
class PasswordController extends _$PasswordController {
  bool _enCours = false;

  @override
  FutureOr<void> build() {}

  Future<AuthFailure?> updatePassword(String newPassword) => _executer(
        () => ref.read(authRepositoryProvider).updatePassword(newPassword),
      );

  /// Envoie le lien à une adresse saisie — écran de connexion, client non
  /// authentifié.
  Future<AuthFailure?> sendPasswordResetEmailTo(String email) => _executer(
        () => ref
            .read(authRepositoryProvider)
            .sendPasswordResetEmailWithEmail(email),
      );

  /// Envoie le lien à l'adresse du compte connecté.
  Future<AuthFailure?> sendPasswordResetEmail() => _executer(
        () => ref.read(authRepositoryProvider).sendPasswordResetEmail(),
      );

  Future<AuthFailure?> _executer(Future<void> Function() operation) async {
    if (_enCours) return null;
    _enCours = true;

    state = const AsyncLoading<void>();
    try {
      await operation();
      if (ref.mounted) state = const AsyncData<void>(null);
      return null;
    } catch (e, st) {
      // Seul point de traduction : le dépôt laisse remonter la
      // `FirebaseAuthException` brute, l'écran ne voit qu'un message français.
      final echec = mapAuthError(e);
      if (ref.mounted) state = AsyncError<void>(echec, st);
      return echec;
    } finally {
      _enCours = false;
    }
  }
}
