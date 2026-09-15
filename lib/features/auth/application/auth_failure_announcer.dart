import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth_failure.dart';

part 'auth_failure_announcer.g.dart';

/// Échec d'authentification à annoncer au client, avec son rang d'arrivée.
///
/// L'[id] existe parce que deux échecs successifs porteurs du même texte sont
/// **égaux** : sans lui, `ref.listen` ne se redéclencherait pas et le client
/// qui tape deux fois sur « Se connecter » ne verrait qu'un seul message.
/// Même raison d'être que `CartSyncFailure.id`.
class AnnouncedAuthFailure {
  const AnnouncedAuthFailure(this.failure, this.id);

  final AuthFailure failure;
  final int id;

  String get message => failure.message;
}

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
@Riverpod(keepAlive: true)
class AuthFailureAnnouncer extends _$AuthFailureAnnouncer {
  int _compteur = 0;

  @override
  AnnouncedAuthFailure? build() => null;

  /// Dépose un échec à montrer. Sans effet si l'échec est silencieux.
  void announce(AuthFailure failure) {
    if (failure.isSilent) return;
    state = AnnouncedAuthFailure(failure, ++_compteur);
  }

  /// Appelé par l'afficheur une fois le message présenté.
  void clear() => state = null;
}
