import 'package:firebase_auth/firebase_auth.dart';

/// Enumération pour les erreurs d'authentification Firebase.
enum AuthError {
  invalidEmail,
  userDisabled,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  operationNotAllowed,
  weakPassword,
  invalidCredential,
  unknown,
}

/// Classe pour gérer les erreurs de FirebaseAuth et les convertir en messages lisibles.
class FirebaseAuthErrorHandler {
  /// Traduit un [FirebaseAuthException] en un [AuthError].
  static AuthError handleException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthError.invalidEmail;
      case 'user-disabled':
        return AuthError.userDisabled;
      case 'user-not-found':
        return AuthError.userNotFound;
      case 'wrong-password':
        return AuthError.wrongPassword;
      case 'invalid-credential':
        return AuthError.invalidCredential;
      case 'email-already-in-use':
        return AuthError.emailAlreadyInUse;
      case 'operation-not-allowed':
        return AuthError.operationNotAllowed;
      case 'weak-password':
        return AuthError.weakPassword;
      default:
        return AuthError.unknown;
    }
  }

  /// Fournit un message d'erreur lisible pour un [AuthError].
  static String getErrorMessage(AuthError error) {
    switch (error) {
      case AuthError.invalidEmail:
        return 'L\'adresse e-mail est mal formatée.';
      case AuthError.userDisabled:
        return 'Ce compte utilisateur a été désactivé.';
      case AuthError.userNotFound:
        return 'Aucun utilisateur trouvé pour cet e-mail.';
      case AuthError.wrongPassword:
      case AuthError.invalidCredential:
        return 'L\'e-mail ou le mot de passe est incorrect.';
      case AuthError.emailAlreadyInUse:
        return 'Cette adresse e-mail est déjà utilisée par un autre compte.';
      case AuthError.operationNotAllowed:
        return 'L\'authentification par e-mail et mot de passe n\'est pas activée.';
      case AuthError.weakPassword:
        return 'Le mot de passe est trop faible.';
      case AuthError.unknown:
        return 'Une erreur inconnue est survenue. Veuillez réessayer.';
    }
  }
}
