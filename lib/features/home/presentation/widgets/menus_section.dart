import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/home/data/remote/menu_controller.dart';
import 'package:lilia_app/features/home/presentation/widgets/menu_card.dart';
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
          return _EmptyMenusState();
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
                      onPressed: () {},
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
                      context.pushNamed(
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

class _EmptyMenusState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menus du Jour',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pas de menu du jour pour l\'instant',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Les menus proposés par le restaurant apparaîtront ici dès qu\'ils seront disponibles.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
