import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../services/analytics_service.dart';
import '../domain/auth_failure.dart';
import '../repository/firebase_auth_repository.dart';
import 'auth_failure_announcer.dart';

part 'sign_in_controller.g.dart';

/// Les trois façons d'ouvrir une session.
enum AuthOperation { emailSignIn, emailSignUp, google }

/// Ce que les écrans d'authentification ont besoin de savoir : **quelle**
/// opération tourne, s'il y en a une.
///
/// Un simple booléen ne suffisait pas. Les boutons « Se connecter » et
/// « Se connecter avec Google » partagent le même contrôleur : avec un seul
/// `isLoading`, lancer Google faisait tourner un indicateur dans les **deux**
/// boutons. Or ils ne doivent pas réagir pareil — tous deux sont grisés, mais
/// seul celui qu'on a touché rend compte de son travail.
class SignInState {
  const SignInState({this.operation});

  /// `null` quand rien n'est en cours.
  final AuthOperation? operation;

  /// Une opération est en cours : **tous** les boutons doivent être grisés.
  /// Deux flux d'authentification concurrents s'annulent mutuellement — le
  /// chemin Google appelle `GoogleSignIn.disconnect()` en préambule.
  bool get isLoading => operation != null;

  /// Cette opération-là est-elle celle qui tourne ? Pilote l'indicateur.
  bool isRunning(AuthOperation op) => operation == op;

  @override
  bool operator ==(Object other) =>
      other is SignInState && other.operation == operation;

  @override
  int get hashCode => operation.hashCode;
}

/// Les opérations **ponctuelles** d'ouverture de session : connexion par
/// e-mail, inscription, connexion Google.
///
/// ## Pourquoi elles ne vivent plus dans `AuthController`
///
/// `AuthController.build()` rend un `Stream<AppUser?>` : son état **signifie**
/// « qui est connecté ». Y écrire `AsyncValue.loading()` puis
/// `AsyncValue.error(...)` pour raconter le déroulement d'une opération faisait
/// dire à cet état deux choses incompatibles. Le symptôme visible : après une
/// connexion Google ratée, l'état restait en `error`, donc `.value` valait
/// `null`, donc `edit_profile_page` affichait « Utilisateur non trouvé » à un
/// client parfaitement connecté.
///
/// Ici, l'état ne répond qu'à une question : **quelle opération est en cours ?**
/// Il ne porte **aucune erreur** — un état d'erreur qui survit à l'opération
/// est précisément ce qui empoisonnait le contrôleur de session.
///
/// ## Où vont les échecs : deux canaux, une règle
///
/// - **Annonce** ([AuthFailureAnnouncer]) quand l'écran d'origine peut avoir
///   disparu avant l'échec — c'est le cas de l'inscription, où Firebase
///   connecte l'utilisateur avant `/users/sync` et déclenche la redirection.
/// - **Valeur de retour** ([AuthFailure] ou `null`) pour l'appelant encore
///   présent qui doit enchaîner — par exemple ne proposer la saisie du numéro
///   qu'après une connexion Google réussie.
///
/// Les deux sont alimentés par le même échec : jamais deux messages.
@riverpod
class SignInController extends _$SignInController {
  @override
  SignInState build() => const SignInState();

  Future<AuthFailure?> signInWithEmail(String email, String password) {
    return _executer(
      AuthOperation.emailSignIn,
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(email: email, password: password),
      surSucces: () => AnalyticsService.trackLogin(method: 'email'),
    );
  }

  Future<AuthFailure?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? referralCode,
  }) {
    return _executer(
      AuthOperation.emailSignUp,
      () => ref.read(authRepositoryProvider).createUserWithEmailAndPassword(
            email: email,
            password: password,
            name: name,
            phone: phone,
            referralCode: referralCode,
          ),
      surSucces: () => AnalyticsService.trackSignUp(method: 'email'),
    );
  }

  /// [referralCode] n'a d'effet que si la connexion Google crée le compte.
  Future<AuthFailure?> signInWithGoogle({String? referralCode}) {
    return _executer(
      AuthOperation.google,
      () => ref
          .read(authRepositoryProvider)
          .signInWithGoogle(referralCode: referralCode),
      surSucces: () => AnalyticsService.trackLogin(method: 'google'),
    );
  }

  /// Déroulé commun : garde anti-double-appel, chargement, traduction,
  /// annonce. Aucune branche ne laisse l'état sur « en cours ».
  Future<AuthFailure?> _executer(
    AuthOperation operation,
    Future<void> Function() action, {
    required void Function() surSucces,
  }) async {
    // Le bouton Google n'avait aucune garde : un double tap lançait deux flux
    // concurrents, et chacun appelait `GoogleSignIn.disconnect()` — donc
    // annulait potentiellement l'autre. Le grisage des boutons ne suffit pas :
    // il ne prend effet qu'à la frame suivante.
    if (state.isLoading) return null;

    // Capturé **avant** le premier await : ce contrôleur est `autoDispose` et
    // l'écran d'inscription disparaît pendant l'opération (la redirection part
    // dès que Firebase a créé le compte, avant `/users/sync`). Lire le provider
    // depuis le `catch` lèverait alors « Cannot use ref after dispose ». Le
    // notifier, lui, est `keepAlive` : la référence reste valable.
    final annonceur = ref.read(authFailureAnnouncerProvider.notifier);

    state = SignInState(operation: operation);
    try {
      await action();
      surSucces();
      return null;
    } catch (e) {
      final echec = mapAuthError(e);
      annonceur.announce(echec);
      return echec;
    } finally {
      if (ref.mounted) state = const SignInState();
    }
  }
}
