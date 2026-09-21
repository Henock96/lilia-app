import 'package:flutter/material.dart';
import 'package:lilia_app/constants/app_size.dart';
import 'package:lilia_app/routing/auth_exit.dart';

/// Coque commune aux deux écrans d'authentification.
///
/// Elle n'existe que pour une chose, mais cette chose ne peut pas vivre dans
/// l'un des deux écrans : **rendre la sortie possible**. Un visiteur arrive ici
/// par un `redirect` qui a remplacé son emplacement (voir `auth_exit.dart`) —
/// la pile est vide, et sans ce qui suit il est enfermé :
///
///  · une flèche de retour, qui remonte au premier écran public ;
///  · `PopScope`, pour que le retour **matériel** d'Android fasse la même
///    chose au lieu de fermer l'application.
///
/// Les deux gestes passent par `goBackFromAuthRoute` : un seul comportement,
/// deux déclencheurs. Les dissocier ferait qu'un jour l'un des deux
/// changerait seul.
///
/// ## Pourquoi la flèche n'est pas dans un `AppBar`
///
/// Ce serait sa place naturelle, et c'est la première version qui a été
/// écrite. Mais une `AppBar` **réserve 56 px de hauteur en plus du contenu** :
/// sur ces deux écrans, qui tiennent tout juste sur un petit téléphone, le
/// bouton « Se connecter avec Google » passait sous la ligne de flottaison.
/// Le test de l'écran de connexion l'a montré immédiatement — il tapait dans
/// le vide.
///
/// Placée dans le flux, la flèche **consomme la marge haute qui existait
/// déjà** au lieu de s'ajouter à elle. L'affordance est la même, la sémantique
/// pour les lecteurs d'écran aussi, et l'écran ne grandit pas.
class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({super.key, required this.child});

  /// Contenu de l'écran, déjà mis en colonne par l'appelant.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // `false` : on ne laisse jamais le système dépiler. Il n'y a rien sous
      // cet écran — un `pop` accepté fermerait l'application.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goBackFromAuthRoute(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.p24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _BoutonRetour(),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoutonRetour extends StatelessWidget {
  const _BoutonRetour();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      // Libellés explicites : `BackButton` retomberait sur le libellé système,
      // et surtout il appelle `Navigator.maybePop`, qui ne fait rien ici
      // puisque la pile est vide.
      tooltip: 'Retour',
      onPressed: () => goBackFromAuthRoute(context),
    );
  }
}
