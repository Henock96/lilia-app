import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../controller/auth_controller.dart';
import '../domain/auth_failure.dart';
import '../domain/orphan_session.dart';
import '../repository/firebase_auth_repository.dart';
import 'auth_failure_announcer.dart';

part 'session_guard.g.dart';

/// Ce qu'il advient d'une session que le serveur n'accepte plus.
///
/// ## Ce qui se passait avant
///
/// `AuthInterceptor` tente **un** rafraîchissement du jeton Firebase sur 401,
/// rejoue la requête, puis laisse l'erreur passer. `ErrorInterceptor` la
/// marque `ApiErrorKind.unauthorized`. Deux dépôts lisaient ce `kind` pour des
/// replis locaux (panier, avis) — mais **personne ne s'occupait de la session
/// elle-même**.
///
/// Résultat pour un compte supprimé côté serveur ou un jeton révoqué : le
/// client restait « connecté » côté Firebase, face à des écrans vides et des
/// messages génériques, indéfiniment. Aucun écran ne pouvait rattraper cet
/// état, et rien ne lui disait de se reconnecter.
///
/// ## Les quatre pièges, et comment ils sont tenus
///
/// 1. **Boucle de déconnexion.** `signOut()` appelle lui-même le serveur
///    (`DELETE /notifications/token`), qui peut répondre 401 à son tour. Le
///    drapeau [_deconnexionEnCours] absorbe ce second passage.
/// 2. **Déconnexions concurrentes.** Un écran lance volontiers trois requêtes
///    en parallèle ; elles échouent toutes les trois. Le drapeau est posé
///    avant le premier `await`, donc avant que la deuxième n'arrive.
/// 3. **Messages en double.** L'annonce est faite une seule fois, au même
///    endroit et sous la même garde.
/// 4. **Destruction inutile de données locales.** Rien n'est effacé ici : on
///    réutilise `AuthController.signOut()`, qui sait déjà quoi invalider.
///
/// ## Pourquoi le drapeau se réarme tout seul
///
/// Il ne couvre **que la durée de la déconnexion**, et non « le reste de la
/// session ». C'est suffisant, et c'est plus sûr : une fois `signOut()`
/// terminé, `currentUser` vaut `null`, et le test de session vide arrête déjà
/// tout 401 ultérieur. Une reconnexion retrouve donc une garde armée sans
/// qu'on ait à observer quoi que ce soit — pas de `ref.listen` dont il
/// faudrait garantir l'installation avant le premier appel réseau.
@Riverpod(keepAlive: true)
class SessionGuard extends _$SessionGuard {
  /// Vrai pendant la déconnexion en cours.
  bool _deconnexionEnCours = false;

  @override
  void build() {}

  /// À appeler sur **toute** erreur d'API. Réagit au 401, et au 403 d'un
  /// compte absent ou révoqué côté Lilia (voir [accountRefusalOf]).
  ///
  /// Ce second cas affichait « Compte non synchronisé » en boucle : un compte
  /// supprimé pendant que le téléphone gardait sa session Firebase ne
  /// retrouvait jamais l'écran de connexion (bug du 24/09/2026).
  Future<void> handle(Object error) async {
    if (error is! ApiException || _deconnexionEnCours) return;
    final refusal = accountRefusalOf(error);
    if (error.kind != ApiErrorKind.unauthorized && refusal == null) return;

    // Un 401 sur une route publique, ou après une déconnexion déjà faite, ne
    // concerne aucune session : ni nettoyage, ni message à un visiteur qui n'a
    // rien demandé.
    if (ref.read(authRepositoryProvider).currentUser == null) return;

    // Compte absent ou révoqué côté Lilia : on déconnecte, sans tenter de
    // resynchroniser — une resynchronisation recréerait en silence un compte
    // supprimé exprès (les scripts de purge n'effacent que la base). Se
    // reconnecter avec le même compte refait la synchronisation.
    _deconnexionEnCours = true;
    try {
      ref
          .read(authFailureAnnouncerProvider.notifier)
          .announce(refusal == null ? kAuthSessionExpired : kAuthAccountGone);
      await ref.read(authControllerProvider.notifier).signOut();
    } finally {
      _deconnexionEnCours = false;
    }
  }
}
