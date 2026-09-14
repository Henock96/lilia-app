import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/repository/firebase_auth_repository.dart';
import '../features/onboarding/application/onboarding_provider.dart';

part 'session_phase.g.dart';

/// Où en est l'application vis-à-vis de la session, en **une** valeur.
///
/// Le routeur ne lisait pas d'état de session : il lisait deux `AsyncValue`
/// indépendants et en tirait un booléen `isLoggedIn`. Deux problèmes de fond
/// suivaient de là :
///
/// * `data(null)` et « pas encore résolu » se ressemblent trop. Le routeur
///   s'en sortait avec un `if (authState.isLoading) return null` — c'est-à-dire
///   « laisse passer » — donc l'accueil se montait avant que quiconque sache
///   s'il y avait une session (U-03). Ailleurs, la même ambiguïté produisait un
///   « Votre session a expiré » au démarrage à froid (M-08).
/// * deux sources se résolvant indépendamment, c'est deux à trois évaluations
///   du `redirect` au lancement, sans qu'aucune ne sache si l'autre est prête.
///
/// [SessionPhase] rend l'attente **explicite** : tant que les deux sources ne
/// sont pas résolues, la phase vaut [SessionPhase.bootstrapping], et le routeur
/// n'a rien d'autre à décider que « montre l'écran de démarrage ».
enum SessionPhase {
  /// Firebase et l'onboarding n'ont pas encore répondu. Ni connecté, ni
  /// déconnecté : **on ne sait pas**.
  bootstrapping,

  /// Premier lancement : l'onboarding n'a jamais été terminé sur cet appareil.
  onboardingRequired,

  /// Résolu, personne n'est connecté.
  unauthenticated,

  /// Résolu, une session Firebase est ouverte.
  authenticated,
}

/// La phase courante, dérivée des deux seules sources qui la déterminent.
///
/// `keepAlive` : le routeur s'y abonne pour la vie de l'application.
///
/// Deux replis volontaires, tous deux hérités du comportement précédent et
/// conservés parce qu'ils vont dans le bon sens :
/// * une **erreur** de lecture de l'onboarding (SharedPreferences indisponible)
///   vaut « déjà fait » — une panne de stockage local ne doit pas coincer un
///   client dans un carrousel de présentation ;
/// * une **erreur** du flux Firebase vaut « déconnecté » — c'est le seul état
///   sûr, et il mène à l'écran de connexion, d'où l'on peut agir.
///
/// Ce qui compte : une erreur **résout** la phase, elle ne la laisse jamais en
/// [SessionPhase.bootstrapping]. Un écran de démarrage dont on ne sort pas
/// serait pire que le flash qu'il remplace.
@Riverpod(keepAlive: true)
SessionPhase sessionPhase(Ref ref) {
  final onboarding = ref.watch(onboardingStatusProvider);
  final auth = ref.watch(authStateChangeProvider);

  // `hasValue || hasError` et non `!isLoading` : un provider qui se rafraîchit
  // repasse par `isLoading` **tout en gardant sa valeur**. Retomber en
  // bootstrap à ce moment-là renverrait le client sur l'écran de démarrage au
  // milieu de sa session.
  final onboardingResolu = onboarding.hasValue || onboarding.hasError;
  final sessionResolue = auth.hasValue || auth.hasError;
  if (!onboardingResolu || !sessionResolue) return SessionPhase.bootstrapping;

  final onboardingFait = onboarding.hasValue ? onboarding.requireValue : true;
  if (!onboardingFait) return SessionPhase.onboardingRequired;

  return auth.value != null
      ? SessionPhase.authenticated
      : SessionPhase.unauthenticated;
}
