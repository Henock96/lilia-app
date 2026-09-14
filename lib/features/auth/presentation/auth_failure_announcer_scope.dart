import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/snackbar.dart';
import '../application/auth_failure_announcer.dart';

/// Affiche les échecs d'authentification, **où que soit le client**.
///
/// ## Le problème qu'il résout
///
/// À l'inscription, Firebase connecte l'utilisateur dès la création du compte,
/// c'est-à-dire **avant** l'appel à `/users/sync`. Le flux `authStateChanges`
/// émet, le routeur redirige vers l'accueil, `SignUpPage` est démontée — et
/// avec elle le `ref.listen` qui devait montrer l'erreur. Quand la
/// synchronisation échouait ensuite et que le compte Firebase était supprimé,
/// le client se retrouvait sur l'écran de connexion, sans compte, **sans un
/// mot d'explication** (B-02). Il recommençait, avec le même résultat, tant
/// que le backend était en panne.
///
/// Monté ici, au-dessus du routeur, cet observateur survit à toutes les
/// navigations : le message part, quel que soit l'écran affiché à l'instant où
/// l'échec arrive.
///
/// ## Pourquoi il est aussi le point d'affichage unique
///
/// Les deux écrans d'authentification interpolaient chacun `'${state.error}'`
/// dans un snackbar — d'où les `Exception: …` et les
/// `GoogleSignInException(code …canceled…)` lus par les clients. Il n'existe
/// désormais qu'un seul endroit où un échec d'authentification devient du
/// texte, et il ne sait afficher qu'un [AuthFailure.message].
class AuthFailureAnnouncerScope extends ConsumerWidget {
  const AuthFailureAnnouncerScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authFailureAnnouncerProvider, (_, annonce) {
      if (annonce == null) return;
      context.showErrorSnack(annonce.message);
      // Consommé : sans cela, revenir sur un écran réafficherait le même
      // message. Même discipline que `pendingNotificationIntentProvider`.
      ref.read(authFailureAnnouncerProvider.notifier).clear();
    });

    return child;
  }
}
