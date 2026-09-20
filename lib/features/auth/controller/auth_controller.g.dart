// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// **La session, et rien d'autre.**
///
/// L'état de ce contrôleur répond à une seule question : *qui est connecté ?*
/// Il vaut `AsyncData(user)` quand quelqu'un l'est, `AsyncData(null)` sinon —
/// et c'est le flux Firebase qui l'écrit, jamais une opération.
///
/// ⚠️ **Ne jamais y écrire depuis une méthode d'action.** Cinq méthodes le
/// faisaient (`sigInInUserWithEmailAndPassword`, `createUserWithEmailAndPassword`,
/// `signInWithGoogle`, `updatePassword`, `sendPasswordResetEmail`) : elles
/// posaient `AsyncValue.loading()` pour dire « ça travaille » et
/// `AsyncValue.data(null)` pour dire « c'est fini ». Dans ce contrôleur-là,
/// `data(null)` veut dire **« personne n'est connecté »** : après un simple
/// changement de mot de passe, `edit_profile_page` — qui lit
/// `ref.watch(authControllerProvider).value` — affichait « Utilisateur non
/// trouvé » à un client dont la session était intacte.
///
/// Ces opérations vivent désormais dans [SignInController] et
/// [PasswordController], dont l'état ne raconte que leur propre déroulement.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// **La session, et rien d'autre.**
///
/// L'état de ce contrôleur répond à une seule question : *qui est connecté ?*
/// Il vaut `AsyncData(user)` quand quelqu'un l'est, `AsyncData(null)` sinon —
/// et c'est le flux Firebase qui l'écrit, jamais une opération.
///
/// ⚠️ **Ne jamais y écrire depuis une méthode d'action.** Cinq méthodes le
/// faisaient (`sigInInUserWithEmailAndPassword`, `createUserWithEmailAndPassword`,
/// `signInWithGoogle`, `updatePassword`, `sendPasswordResetEmail`) : elles
/// posaient `AsyncValue.loading()` pour dire « ça travaille » et
/// `AsyncValue.data(null)` pour dire « c'est fini ». Dans ce contrôleur-là,
/// `data(null)` veut dire **« personne n'est connecté »** : après un simple
/// changement de mot de passe, `edit_profile_page` — qui lit
/// `ref.watch(authControllerProvider).value` — affichait « Utilisateur non
/// trouvé » à un client dont la session était intacte.
///
/// Ces opérations vivent désormais dans [SignInController] et
/// [PasswordController], dont l'état ne raconte que leur propre déroulement.
final class AuthControllerProvider
    extends $StreamNotifierProvider<AuthController, AppUser?> {
  /// **La session, et rien d'autre.**
  ///
  /// L'état de ce contrôleur répond à une seule question : *qui est connecté ?*
  /// Il vaut `AsyncData(user)` quand quelqu'un l'est, `AsyncData(null)` sinon —
  /// et c'est le flux Firebase qui l'écrit, jamais une opération.
  ///
  /// ⚠️ **Ne jamais y écrire depuis une méthode d'action.** Cinq méthodes le
  /// faisaient (`sigInInUserWithEmailAndPassword`, `createUserWithEmailAndPassword`,
  /// `signInWithGoogle`, `updatePassword`, `sendPasswordResetEmail`) : elles
  /// posaient `AsyncValue.loading()` pour dire « ça travaille » et
  /// `AsyncValue.data(null)` pour dire « c'est fini ». Dans ce contrôleur-là,
  /// `data(null)` veut dire **« personne n'est connecté »** : après un simple
  /// changement de mot de passe, `edit_profile_page` — qui lit
  /// `ref.watch(authControllerProvider).value` — affichait « Utilisateur non
  /// trouvé » à un client dont la session était intacte.
  ///
  /// Ces opérations vivent désormais dans [SignInController] et
  /// [PasswordController], dont l'état ne raconte que leur propre déroulement.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'371aa8756fa2e540bd865cb88ef9c79b8ce95768';

/// **La session, et rien d'autre.**
///
/// L'état de ce contrôleur répond à une seule question : *qui est connecté ?*
/// Il vaut `AsyncData(user)` quand quelqu'un l'est, `AsyncData(null)` sinon —
/// et c'est le flux Firebase qui l'écrit, jamais une opération.
///
/// ⚠️ **Ne jamais y écrire depuis une méthode d'action.** Cinq méthodes le
/// faisaient (`sigInInUserWithEmailAndPassword`, `createUserWithEmailAndPassword`,
/// `signInWithGoogle`, `updatePassword`, `sendPasswordResetEmail`) : elles
/// posaient `AsyncValue.loading()` pour dire « ça travaille » et
/// `AsyncValue.data(null)` pour dire « c'est fini ». Dans ce contrôleur-là,
/// `data(null)` veut dire **« personne n'est connecté »** : après un simple
/// changement de mot de passe, `edit_profile_page` — qui lit
/// `ref.watch(authControllerProvider).value` — affichait « Utilisateur non
/// trouvé » à un client dont la session était intacte.
///
/// Ces opérations vivent désormais dans [SignInController] et
/// [PasswordController], dont l'état ne raconte que leur propre déroulement.

abstract class _$AuthController extends $StreamNotifier<AppUser?> {
  Stream<AppUser?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppUser?>, AppUser?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppUser?>, AppUser?>,
              AsyncValue<AppUser?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
