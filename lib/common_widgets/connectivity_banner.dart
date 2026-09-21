import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../theme/lilia_tokens.dart';

/// **L'état du réseau, dit sans rien déplacer.**
///
/// ## Ce qu'il remplace
///
/// Deux widgets pour un besoin, et aucun ne fonctionnait : `ConnectivityBanner`
/// n'était monté nulle part, et `ConnectivityWrapper` appelait
/// `ScaffoldMessenger.of` depuis un contexte situé **au-dessus** de
/// `MaterialApp` — donc au-dessus du `ScaffoldMessenger` que `MaterialApp`
/// installe. L'appel levait à chaque bascule de réseau.
///
/// ## Deux corrections d'affichage
///
/// **(1) Plus de décalage de la mise en page.** La première version posait la
/// bannière dans une `Column`, au-dessus de l'application : elle prenait de la
/// hauteur, et **l'`AppBar` de l'écran courant descendait d'autant**. Avec la
/// `SafeArea` par-dessus, le décalage atteignait la hauteur de l'encoche. Un
/// indicateur d'état n'a pas à réorganiser l'écran qu'il commente.
///
/// Le bandeau est désormais **posé par-dessus**, dans un `Stack` : il flotte
/// au-dessus du contenu, près du bas, là où vivent les messages éphémères de
/// Material. Le reste de l'arbre ne bouge pas d'un pixel, qu'il soit visible
/// ou non.
///
/// **(2) Plus de message qui reste.** Le rétablissement passait par un
/// `SnackBar`, c'est-à-dire par un objet dont la disparition dépend d'un
/// minuteur et d'un `removeCurrentSnackBar` — deux occasions de rater. Il n'y
/// a plus qu'un seul élément à l'écran, et son apparence est une **fonction de
/// l'état** :
///
/// ```text
/// hors ligne        → bandeau rouge, tant que ça dure
/// retour en ligne   → bandeau vert « Connexion rétablie », 2,5 s
/// en ligne          → rien
/// ```
///
/// Rien à retirer : quand l'état change, le bandeau suit. C'est aussi ce qui
/// supprime définitivement la dépendance au `ScaffoldMessenger`, et avec elle
/// la classe de défaut du point (2) ci-dessus.
class ConnectivityGate extends ConsumerStatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends ConsumerState<ConnectivityGate> {
  /// Combien de temps « Connexion rétablie » reste affiché.
  static const _dureeRetabli = Duration(milliseconds: 2500);

  /// Hauteur réservée sous le bandeau pour dégager la barre d'onglets.
  ///
  /// La coque en fait 65 (`BottomNavigationPage`) ; on ajoute une marge. Sur
  /// les écrans qui n'en ont pas — connexion, paiement — le bandeau flotte
  /// simplement un peu plus haut, ce qui ne gêne rien.
  static const _degagementBarreOnglets = 78.0;

  bool _retabli = false;
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  void _annoncerRetablissement() {
    _minuteur?.cancel();
    setState(() => _retabli = true);
    _minuteur = Timer(_dureeRetabli, () {
      if (mounted) setState(() => _retabli = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(connectivityStatusProvider, (avant, apres) {
      final etait = avant?.value;
      final est = apres.value;
      // Le premier état connu n'est pas une transition : il n'y a rien à
      // annoncer à quelqu'un qui vient d'ouvrir l'application.
      if (est == null || etait == null || etait == est) return;
      if (est) {
        _annoncerRetablissement();
      } else {
        // Retour hors ligne : le bandeau rouge reprend la main tout de suite.
        _minuteur?.cancel();
        if (_retabli) setState(() => _retabli = false);
      }
    });

    final horsLigne = ref.watch(
      connectivityStatusProvider.select((s) => s.value == false),
    );
    final visible = horsLigne || _retabli;

    return Stack(
      children: [
        // ⚠️ `Positioned.fill` et non un enfant direct : l'application occupe
        // exactement la même place, bandeau ou pas. C'est tout l'objet du
        // passage de `Column` à `Stack`.
        Positioned.fill(child: widget.child),
        Positioned(
          left: 16,
          right: 16,
          bottom:
              MediaQuery.of(context).viewPadding.bottom +
              _degagementBarreOnglets,
          child: IgnorePointer(
            // Purement informatif : il ne doit jamais intercepter un tap
            // destiné à ce qu'il survole.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (enfant, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: enfant,
                ),
              ),
              // ⚠️ `AnimatedSwitcher` et non `AnimatedOpacity` : avec ce
              // dernier, le bandeau **reste dans l'arbre** à opacité nulle.
              // Invisible à l'œil, mais bien présent — un lecteur d'écran
              // annoncerait « Connexion rétablie » en permanence, et un test
              // le trouverait alors qu'il n'est pas affiché. Ici, l'état caché
              // est une boîte vide : il n'y a réellement rien.
              child: visible
                  ? _Bandeau(
                      key: ValueKey<bool>(horsLigne),
                      horsLigne: horsLigne,
                    )
                  : const SizedBox.shrink(key: ValueKey<String>('aucun')),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({super.key, required this.horsLigne});

  final bool horsLigne;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: horsLigne ? LiliaColors.red400 : LiliaColors.green500,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              horsLigne ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                horsLigne
                    ? 'Pas de connexion internet'
                    : 'Connexion rétablie',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
