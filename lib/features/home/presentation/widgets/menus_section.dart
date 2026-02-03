import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/home/data/remote/menu_controller.dart';
import 'package:lilia_app/features/home/presentation/widgets/menu_card.dart';
import 'package:lilia_app/models/menu.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

class MenusSection extends ConsumerWidget {
  final String? restaurantId;

  const MenusSection({super.key, this.restaurantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menusAsyncValue = ref.watch(activeMenusProvider(restaurantId));

    return menusAsyncValue.when(
      data: (menus) {
        if (menus.isEmpty) {
          return const SizedBox.shrink(); // Pas de menus, ne rien afficher
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Menus du Jour',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (menus.length > 3)
                    TextButton(
                      onPressed: () {
                        // TODO: Naviguer vers une page avec tous les menus
                      },
                      child: const Text('Voir tout'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: menus.length,
                itemBuilder: (context, index) {
                  final menu = menus[index];
                  return MenuCard(
                    menu: menu,
                    onTap: () {
                      context.goNamed(
                        AppRoutes.menuDetail.routeName,
                        extra: menu,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Erreur lors du chargement des menus',
          style: TextStyle(color: Colors.red[400]),
        ),
      ),
    );
  }
}
