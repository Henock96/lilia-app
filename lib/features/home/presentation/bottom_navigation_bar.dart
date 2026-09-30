import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/features/auth/presentation/guest_tab_prompt.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/routing/protected_locations.dart';
import 'package:lilia_app/routing/session_phase.dart';
import 'package:lilia_app/utils/snackbar.dart';

class BottomNavigationPage extends ConsumerStatefulWidget {
  const BottomNavigationPage({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<BottomNavigationPage> createState() =>
      _BottomNavigationPageState();
}

class _BottomNavigationPageState extends ConsumerState<BottomNavigationPage> {
  /// Onglet réservé tapé par un visiteur : la coque montre une invitation à
  /// sa place (P3-18). `null` : l'onglet courant du routeur est affiché.
  int? _invitation;

  /// Bascule d'onglet, **en repassant par le garde d'authentification**.
  ///
  /// `goBranch` change de pile sans déclencher `redirect` : c'était le seul
  /// chemin de l'application qui échappait à `resolveRedirect`. Un invité
  /// tapant « Commandes » ou « Profil » arrivait donc sur un écran qui
  /// interroge des routes authentifiées, et n'y voyait qu'une erreur.
  ///
  /// La question posée est la **même** que celle du routeur —
  /// `requiresAuthentication`. Sans session, l'onglet n'est pas ouvert :
  /// la coque affiche une invitation ([GuestTabPrompt]) **en gardant sa
  /// barre**, avec l'accès au support et à « À propos ». Elle menait
  /// auparavant à la connexion en plein écran, sans contexte ni issue
  /// (P3-18). La connexion, depuis l'invitation, ramène sur l'onglet voulu.
  void _goBranch(int index) {
    final destination = kShellBranchLocations[index];
    if (requiresAuthentication(destination) &&
        ref.read(sessionPhaseProvider) != SessionPhase.authenticated) {
      setState(() => _invitation = index);
      return;
    }

    // Quitter l'invitation pour l'onglet déjà ouvert dessous le rend tel
    // qu'il était : ce n'est pas un « retap » de l'onglet actif.
    final quitteInvitation = _invitation != null;
    if (quitteInvitation) setState(() => _invitation = null);

    widget.navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active. This example demonstrates how to support this behavior,
      // using the initialLocation parameter of goBranch.
      initialLocation:
          !quitteInvitation && index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void didUpdateWidget(covariant BottomNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Toute navigation du routeur (lien, notification, connexion) l'emporte
    // sur l'invitation : elle ne doit jamais masquer l'écran demandé.
    if (!identical(oldWidget.navigationShell, widget.navigationShell)) {
      _invitation = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Les mutations du panier rendent la main avant le réseau : quand la
    // synchronisation échoue, le changement est défait à l'écran et le motif
    // arrive ici. C'est le **seul** point d'écoute de l'application — la coque
    // est montée sous tous les écrans d'où l'on peut ajouter au panier
    // (catalogue, fiche produit, recherche, favoris, panier).
    ref.listen(cartSyncFailuresProvider, (_, echec) {
      if (echec != null) context.showErrorSnack(echec.message);
    });

    // Une session ouverte rend l'invitation caduque.
    final authentifie =
        ref.watch(sessionPhaseProvider) == SessionPhase.authenticated;
    final invitation = authentifie ? null : _invitation;

    return PopScope(
      // Le retour système Android quittait l'application depuis n'importe quel
      // onglet : la racine d'une branche n'a rien à dépiler, et il n'y avait
      // aucun `PopScope` au niveau de la coque. Depuis « Commandes », « retour »
      // fermait donc Lilia Food au lieu de revenir à l'accueil.
      //
      // On n'intercepte que depuis un onglet secondaire : sur l'accueil, le
      // retour doit continuer de sortir de l'application, comme partout ailleurs
      // sur Android.
      //
      // L'invitation se referme d'abord : elle recouvre un onglet, le retour
      // y ramène.
      canPop: widget.navigationShell.currentIndex == 0 && invitation == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (invitation != null) {
          setState(() => _invitation = null);
          return;
        }
        widget.navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: SafeArea(
          // `IndexedStack` et non un remplacement : les piles des onglets
          // (défilement de l'accueil, fiche ouverte) survivent à l'invitation.
          child: IndexedStack(
            index: invitation == null ? 0 : 1,
            children: [
              widget.navigationShell,
              if (invitation != null)
                _invitationPour(invitation)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 65,
          elevation: 0,
          selectedIndex: invitation ?? widget.navigationShell.currentIndex,
          destinations: const [
            NavigationDestination(label: 'Accueil', icon: Icon(Iconsax.home)),
            NavigationDestination(label: 'Panier', icon: _CartIcon()),
            NavigationDestination(label: 'Commandes', icon: Icon(Iconsax.shop)),
            NavigationDestination(label: 'Profil', icon: Icon(Iconsax.user)),
          ],
          onDestinationSelected: _goBranch,
        ),
      ),
    );
  }
}

/// Invitation d'un onglet réservé, selon l'onglet tapé.
///
/// Chaque bénéfice correspond à une fonctionnalité **présente** :
/// Commandes — timeline et suivi du livreur, `reorder_action.dart`,
/// réclamation après livraison (`claims/`, F3-06) ; Profil — `address/`,
/// `favoris/` (plats et boutiques), carte de fidélité et parrainage.
/// N'en ajouter aucune qui ne soit pas livrée.
GuestTabPrompt _invitationPour(int index) {
  final location = kShellBranchLocations[index];
  return location == AppRoutes.profile.path
      ? GuestTabPrompt(
          key: const ValueKey('guest_prompt_profile'),
          location: location,
          title: 'Mon profil',
          message:
              'Un compte garde vos informations d\'une commande à '
              'l\'autre.',
          image: 'assets/onboarding/onb1.webp',
          imageAlignment: const Alignment(0, -0.1),
          benefits: const [
            GuestBenefit(
              Iconsax.location,
              'Vos adresses de livraison enregistrées',
            ),
            GuestBenefit(Iconsax.heart, 'Vos plats et boutiques favoris'),
            GuestBenefit(
              Iconsax.gift,
              'Des points de fidélité, et le parrainage de vos proches',
            ),
          ],
        )
      : GuestTabPrompt(
          key: const ValueKey('guest_prompt_orders'),
          location: location,
          title: 'Mes commandes',
          message: 'Connectez-vous pour commander et suivre vos commandes.',
          image: 'assets/onboarding/onb2.webp',
          imageAlignment: const Alignment(0, -0.3),
          benefits: const [
            GuestBenefit(
              Iconsax.routing,
              'Suivez la préparation puis la livraison',
            ),
            GuestBenefit(
              Iconsax.refresh,
              'Retrouvez votre historique et recommandez en un geste',
            ),
            GuestBenefit(
              Iconsax.message_question,
              'Signalez un problème après la remise',
            ),
          ],
        );
}

/// Icône « Panier » et son compteur.
///
/// Le panier étant désormais mis à jour localement avant le réseau, ce
/// compteur bouge **dans la frame du tap**. Il existe pour cette raison : le
/// message éphémère était jusqu'ici le seul témoin d'un ajout, et il disparaît.
///
/// Widget séparé et `select` sur le seul `totalItems` : la coque de navigation
/// — donc les quatre onglets et tout ce qu'ils portent — ne doit pas se
/// reconstruire parce qu'un prix ou une image a changé dans le panier.
class _CartIcon extends ConsumerWidget {
  const _CartIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      cartControllerProvider.select((cart) => cart.value?.totalItems ?? 0),
    );

    if (total == 0) return const Icon(Iconsax.shopping_bag);

    return Badge(
      label: Text('$total'),
      child: const Icon(Iconsax.shopping_bag),
    );
  }
}
