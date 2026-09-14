// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_in_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(SignInController)
final signInControllerProvider = SignInControllerProvider._();

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
final class SignInControllerProvider
    extends $NotifierProvider<SignInController, SignInState> {
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
  SignInControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signInControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signInControllerHash();

  @$internal
  @override
  SignInController create() => SignInController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignInState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignInState>(value),
    );
  }
}

String _$signInControllerHash() => r'147888602fb8add30d57745c924c8ee85c0cec13';

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

abstract class _$SignInController extends $Notifier<SignInState> {
  SignInState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SignInState, SignInState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SignInState, SignInState>,
              SignInState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
