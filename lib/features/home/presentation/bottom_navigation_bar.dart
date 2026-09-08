import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/utils/snackbar.dart';

class BottomNavigationPage extends ConsumerStatefulWidget {
  const BottomNavigationPage({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<BottomNavigationPage> createState() =>
      _BottomNavigationPageState();
}

class _BottomNavigationPageState extends ConsumerState<BottomNavigationPage> {
  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active. This example demonstrates how to support this behavior,
      // using the initialLocation parameter of goBranch.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
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

    return Scaffold(
      body: SafeArea(child: widget.navigationShell),
      bottomNavigationBar: NavigationBar(
        height: 65,
        elevation: 0,
        selectedIndex: widget.navigationShell.currentIndex,
        destinations: const [
          NavigationDestination(label: 'Accueil', icon: Icon(Iconsax.home)),
          NavigationDestination(label: 'Panier', icon: _CartIcon()),
          NavigationDestination(label: 'Commandes', icon: Icon(Iconsax.shop)),
          NavigationDestination(label: 'Profil', icon: Icon(Iconsax.user)),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
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
