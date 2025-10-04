import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

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
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        height: 65,
        elevation: 0,
        selectedIndex: widget.navigationShell.currentIndex,
        destinations: const [
          NavigationDestination(label: 'Accueil', icon: Icon(Iconsax.home)),
          NavigationDestination(
            label: 'Panier',
            icon: Icon(Iconsax.shopping_bag),
          ),
          NavigationDestination(label: 'Commandes', icon: Icon(Iconsax.shop)),
          NavigationDestination(label: 'Profil', icon: Icon(Iconsax.user)),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}
