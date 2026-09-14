// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_failure_announcer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Canal unique des échecs d'authentification à montrer.
///
/// ## Pourquoi il ne suffit pas de poser l'erreur dans l'état du contrôleur
///
/// À l'inscription, Firebase connecte l'utilisateur **avant** l'appel à
/// `/users/sync` : le flux `authStateChanges` émet, le routeur redirige vers
/// l'accueil, et `SignUpPage` est démontée — donc son `ref.listen` est annulé.
/// Quand la synchronisation échoue ensuite et que le compte Firebase est
/// supprimé, le message d'erreur n'a **plus personne pour l'afficher** : le
/// client revient sur l'écran de connexion sans son compte et sans un mot
/// d'explication. C'était B-02.
///
/// Ce notifier est `keepAlive` : ce qu'on y dépose survit à n'importe quelle
/// navigation. `AuthFailureAnnouncerScope`, monté au-dessus du routeur, le lit
/// et affiche le message où que se trouve le client à cet instant.
///
/// ⚠️ Une annulation n'entre jamais ici — voir [AuthFailure.isSilent].

@ProviderFor(AuthFailureAnnouncer)
final authFailureAnnouncerProvider = AuthFailureAnnouncerProvider._();

/// Canal unique des échecs d'authentification à montrer.
///
/// ## Pourquoi il ne suffit pas de poser l'erreur dans l'état du contrôleur
///
/// À l'inscription, Firebase connecte l'utilisateur **avant** l'appel à
/// `/users/sync` : le flux `authStateChanges` émet, le routeur redirige vers
/// l'accueil, et `SignUpPage` est démontée — donc son `ref.listen` est annulé.
/// Quand la synchronisation échoue ensuite et que le compte Firebase est
/// supprimé, le message d'erreur n'a **plus personne pour l'afficher** : le
/// client revient sur l'écran de connexion sans son compte et sans un mot
/// d'explication. C'était B-02.
///
/// Ce notifier est `keepAlive` : ce qu'on y dépose survit à n'importe quelle
/// navigation. `AuthFailureAnnouncerScope`, monté au-dessus du routeur, le lit
/// et affiche le message où que se trouve le client à cet instant.
///
/// ⚠️ Une annulation n'entre jamais ici — voir [AuthFailure.isSilent].
final class AuthFailureAnnouncerProvider
    extends $NotifierProvider<AuthFailureAnnouncer, AnnouncedAuthFailure?> {
  /// Canal unique des échecs d'authentification à montrer.
  ///
  /// ## Pourquoi il ne suffit pas de poser l'erreur dans l'état du contrôleur
  ///
  /// À l'inscription, Firebase connecte l'utilisateur **avant** l'appel à
  /// `/users/sync` : le flux `authStateChanges` émet, le routeur redirige vers
  /// l'accueil, et `SignUpPage` est démontée — donc son `ref.listen` est annulé.
  /// Quand la synchronisation échoue ensuite et que le compte Firebase est
  /// supprimé, le message d'erreur n'a **plus personne pour l'afficher** : le
  /// client revient sur l'écran de connexion sans son compte et sans un mot
  /// d'explication. C'était B-02.
  ///
  /// Ce notifier est `keepAlive` : ce qu'on y dépose survit à n'importe quelle
  /// navigation. `AuthFailureAnnouncerScope`, monté au-dessus du routeur, le lit
  /// et affiche le message où que se trouve le client à cet instant.
  ///
  /// ⚠️ Une annulation n'entre jamais ici — voir [AuthFailure.isSilent].
  AuthFailureAnnouncerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authFailureAnnouncerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authFailureAnnouncerHash();

  @$internal
  @override
  AuthFailureAnnouncer create() => AuthFailureAnnouncer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnnouncedAuthFailure? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnnouncedAuthFailure?>(value),
    );
  }
}

String _$authFailureAnnouncerHash() =>
    r'1313d6c55de2cad9565b0aad626079ec9e245d71';

/// Canal unique des échecs d'authentification à montrer.
///
/// ## Pourquoi il ne suffit pas de poser l'erreur dans l'état du contrôleur
///
/// À l'inscription, Firebase connecte l'utilisateur **avant** l'appel à
/// `/users/sync` : le flux `authStateChanges` émet, le routeur redirige vers
/// l'accueil, et `SignUpPage` est démontée — donc son `ref.listen` est annulé.
/// Quand la synchronisation échoue ensuite et que le compte Firebase est
/// supprimé, le message d'erreur n'a **plus personne pour l'afficher** : le
/// client revient sur l'écran de connexion sans son compte et sans un mot
/// d'explication. C'était B-02.
///
/// Ce notifier est `keepAlive` : ce qu'on y dépose survit à n'importe quelle
/// navigation. `AuthFailureAnnouncerScope`, monté au-dessus du routeur, le lit
/// et affiche le message où que se trouve le client à cet instant.
///
/// ⚠️ Une annulation n'entre jamais ici — voir [AuthFailure.isSilent].

abstract class _$AuthFailureAnnouncer extends $Notifier<AnnouncedAuthFailure?> {
  AnnouncedAuthFailure? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AnnouncedAuthFailure?, AnnouncedAuthFailure?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AnnouncedAuthFailure?, AnnouncedAuthFailure?>,
              AnnouncedAuthFailure?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
