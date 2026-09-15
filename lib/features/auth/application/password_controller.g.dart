// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(PasswordController)
final passwordControllerProvider = PasswordControllerProvider._();

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
final class PasswordControllerProvider
    extends $AsyncNotifierProvider<PasswordController, void> {
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
  PasswordControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passwordControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passwordControllerHash();

  @$internal
  @override
  PasswordController create() => PasswordController();
}

String _$passwordControllerHash() =>
    r'4e0a24bfeadc475d6b154ce9dae83cce4295f73c';

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

abstract class _$PasswordController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
