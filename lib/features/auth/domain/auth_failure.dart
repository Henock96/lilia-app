import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_exception.dart';

/// Nature d'un échec d'authentification, **du point de vue du client**.
///
/// ## Pourquoi cette couche existe
///
/// L'application avait déjà un excellent contrat d'erreur — mais seulement pour
/// le réseau : `ErrorInterceptor` traduit toute `DioException` en
/// [ApiException] porteuse d'un message français. Ce contrat **s'arrêtait à la
/// porte de Firebase et de Google**. Conséquence mesurée en audit : la même
/// application savait dire « Connexion impossible. Vérifiez votre réseau. »
/// pour un `GET /orders/my`, et disait « Une erreur inconnue est survenue »
/// pour exactement la même panne pendant une connexion.
///
/// Trois fuites concrètes ont motivé ce fichier :
///
/// | Chemin | Ce que lisait le client |
/// |---|---|
/// | Annulation de Google | `GoogleSignInException(code GoogleSignInExceptionCode.canceled, null, null)` |
/// | Mot de passe oublié, e-mail inconnu | `[firebase_auth/user-not-found] There is no user record…` |
/// | Panne backend pendant une connexion Google | `Exception: Erreur réseau: Impossible de se connecter au serveur` |
///
/// ## Les trois règles
///
/// 1. **On traduit depuis le code, jamais depuis le message.** Le code est une
///    valeur stable et énumérée ; le `message` d'une `FirebaseAuthException`
///    est du texte anglais rédigé par Google, qu'on ne contrôle pas.
/// 2. **Une annulation n'est pas une erreur.** Fermer le sélecteur de compte
///    Google est un geste normal : [AuthFailureKind.cancelled] est *silencieux*
///    et l'interface ne doit rien afficher.
/// 3. **Un message du backend passe intact.** Le serveur rédige en français et
///    nomme la cause ; le remplacer par un générique perdrait la seule
///    information utile.
enum AuthFailureKind {
  /// Le client a fermé le sélecteur de compte, ou le flux a été interrompu.
  /// **Ne produit aucun message** — voir [AuthFailure.isSilent].
  cancelled,

  network,
  timeout,

  /// Identifiants refusés. Recouvre volontairement `wrong-password`,
  /// `invalid-credential` **et** `user-not-found` : les distinguer permettrait
  /// à un tiers de savoir quelles adresses ont un compte Lilia Food.
  badCredentials,

  invalidEmail,
  accountDisabled,
  emailAlreadyInUse,
  weakPassword,
  rateLimited,

  /// Opération sensible demandée sur une session trop ancienne.
  requiresRecentLogin,

  /// Le jeton n'est plus valable : il faut se reconnecter.
  sessionExpired,

  /// L'adresse est déjà rattachée à une autre méthode de connexion.
  accountConflict,

  /// La méthode de connexion est désactivée côté projet Firebase.
  operationNotAllowed,

  /// Refus métier du backend. [AuthFailure.message] porte le texte du serveur.
  server,

  unknown,
}

/// Échec d'authentification prêt à être affiché.
///
/// [message] est **toujours** en français et destiné à un humain ; il est vide
/// quand [isSilent] vaut `true`.
class AuthFailure implements Exception {
  const AuthFailure(this.kind, this.message);

  final AuthFailureKind kind;

  /// Message client. Vide si et seulement si [isSilent].
  final String message;

  /// Rien à afficher : le client sait déjà ce qui s'est passé, il l'a voulu.
  bool get isSilent => kind == AuthFailureKind.cancelled;

  /// Filet de sécurité. Si un `'$error'` oublié subsiste quelque part, le
  /// client lit quand même une phrase française plutôt que
  /// `Instance of 'AuthFailure'`. Même parti pris qu'[ApiException].
  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      other is AuthFailure && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);
}

// ─── Messages ────────────────────────────────────────────────────────────────
//
// Vouvoiement, comme partout ailleurs dans l'application. Chaque message dit ce
// qui s'est passé **et** ce que le client peut faire ensuite : un message qui
// ne mène à aucune action ne vaut pas mieux qu'un code d'erreur.

const _kNetwork = 'Connexion impossible. Vérifiez votre réseau puis réessayez.';
const _kTimeout = 'Le serveur met trop de temps à répondre. Réessayez dans un '
    'instant.';
const _kBadCredentials = 'Adresse e-mail ou mot de passe incorrect.';
const _kInvalidEmail = 'Cette adresse e-mail n’est pas valide.';
const _kAccountDisabled = 'Ce compte a été désactivé. Contactez-nous si vous '
    'pensez qu’il s’agit d’une erreur.';
const _kEmailInUse = 'Cette adresse e-mail est déjà utilisée.';
const _kWeakPassword = 'Ce mot de passe est trop simple. Choisissez-en un d’au '
    'moins 6 caractères.';
const _kRateLimited = 'Trop de tentatives. Patientez quelques instants avant '
    'de réessayer.';
const _kRequiresRecentLogin = 'Par sécurité, reconnectez-vous avant de faire '
    'cette modification.';
const _kSessionExpired = 'Votre session a expiré. Reconnectez-vous pour '
    'continuer.';
const _kAccountConflict = 'Un compte existe déjà avec cette adresse e-mail. '
    'Connectez-vous avec la méthode utilisée à l’inscription.';
const _kOperationNotAllowed = 'Cette méthode de connexion n’est pas disponible '
    'pour le moment.';
const _kUnknown = 'Une erreur est survenue. Veuillez réessayer.';

/// Annulation — le seul échec sans message.
const kAuthCancelled = AuthFailure(AuthFailureKind.cancelled, '');

/// Repli, pour les états que les SDK déclarent possibles sans qu'on sache les
/// nommer (un `UserCredential` sans `user`, un jeton Google absent).
const kAuthUnknown = AuthFailure(AuthFailureKind.unknown, _kUnknown);

/// Session invalidée — le jeton n'est plus accepté par le serveur.
const kAuthSessionExpired =
    AuthFailure(AuthFailureKind.sessionExpired, _kSessionExpired);

/// Le téléphone gardait la session d'un compte supprimé (ou suspendu) côté
/// Lilia : on revient à l'écran de connexion, où un autre compte peut servir.
const kAuthAccountGone = AuthFailure(
  AuthFailureKind.sessionExpired,
  'Ce compte n’est plus disponible sur Lilia Food. '
  'Connectez-vous avec un autre compte.',
);

/// Traduit **n'importe quel** échec technique en [AuthFailure].
///
/// Point de passage unique des trois sources d'erreur de l'authentification :
/// Firebase, Google Sign-In et l'API Lilia. Les écrans n'appellent jamais
/// `error.toString()` : ils lisent [AuthFailure.message].
AuthFailure mapAuthError(Object error) {
  if (error is AuthFailure) return error;
  if (error is FirebaseAuthException) return _fromFirebase(error);
  if (error is GoogleSignInException) return _fromGoogle(error);
  if (error is ApiException) return _fromApi(error);
  return const AuthFailure(AuthFailureKind.unknown, _kUnknown);
}

AuthFailure _fromFirebase(FirebaseAuthException e) {
  switch (e.code) {
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
    // Neutralisé délibérément : voir [AuthFailureKind.badCredentials].
    case 'user-not-found':
      return const AuthFailure(AuthFailureKind.badCredentials,
          _kBadCredentials);

    case 'invalid-email':
      return const AuthFailure(AuthFailureKind.invalidEmail, _kInvalidEmail);

    case 'user-disabled':
      return const AuthFailure(AuthFailureKind.accountDisabled,
          _kAccountDisabled);

    case 'email-already-in-use':
      return const AuthFailure(AuthFailureKind.emailAlreadyInUse, _kEmailInUse);

    case 'weak-password':
      return const AuthFailure(AuthFailureKind.weakPassword, _kWeakPassword);

    case 'too-many-requests':
      return const AuthFailure(AuthFailureKind.rateLimited, _kRateLimited);

    case 'network-request-failed':
      return const AuthFailure(AuthFailureKind.network, _kNetwork);

    case 'requires-recent-login':
      return const AuthFailure(AuthFailureKind.requiresRecentLogin,
          _kRequiresRecentLogin);

    case 'operation-not-allowed':
      return const AuthFailure(AuthFailureKind.operationNotAllowed,
          _kOperationNotAllowed);

    case 'credential-already-in-use':
    case 'account-exists-with-different-credential':
    case 'provider-already-linked':
      return const AuthFailure(AuthFailureKind.accountConflict,
          _kAccountConflict);

    case 'user-token-expired':
    case 'user-token-revoked':
    case 'invalid-user-token':
      return const AuthFailure(AuthFailureKind.sessionExpired,
          _kSessionExpired);

    default:
      return const AuthFailure(AuthFailureKind.unknown, _kUnknown);
  }
}

AuthFailure _fromGoogle(GoogleSignInException e) {
  switch (e.code) {
    // Les deux seuls cas où le client sait déjà ce qui s'est passé.
    // `interrupted` couvre la bascule d'application ou l'appel entrant : il n'a
    // rien demandé, mais lui montrer une erreur ne l'avancerait pas davantage.
    case GoogleSignInExceptionCode.canceled:
    case GoogleSignInExceptionCode.interrupted:
      return kAuthCancelled;

    // `description` porte du texte de plateforme
    // (`PlatformException(sign_in_failed, ApiException: 10)`) : il ne sort pas
    // d'ici.
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      return const AuthFailure(AuthFailureKind.operationNotAllowed,
          _kOperationNotAllowed);

    // L'enum est documenté comme extensible sans casse : un `default` est donc
    // obligatoire, et une valeur ajoutée demain tombera sur un message correct.
    default:
      return const AuthFailure(AuthFailureKind.unknown, _kUnknown);
  }
}

AuthFailure _fromApi(ApiException e) {
  switch (e.kind) {
    case ApiErrorKind.network:
      return const AuthFailure(AuthFailureKind.network, _kNetwork);
    case ApiErrorKind.timeout:
      return const AuthFailure(AuthFailureKind.timeout, _kTimeout);
    case ApiErrorKind.unauthorized:
      return const AuthFailure(AuthFailureKind.sessionExpired,
          _kSessionExpired);
    case ApiErrorKind.server:
    case ApiErrorKind.client:
    case ApiErrorKind.unknown:
      // `ErrorInterceptor` garantit déjà un message français : soit celui du
      // serveur (« Vous avez 1 commande(s) en cours. »), soit son repli.
      final message = e.message.trim();
      if (message.isEmpty) {
        return const AuthFailure(AuthFailureKind.unknown, _kUnknown);
      }
      return AuthFailure(AuthFailureKind.server, message);
  }
}
