import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/restaurant.dart';
import '../../../../services/analytics_service.dart';
import '../../data/remote/home_controller.dart';
import 'shimmer_box.dart';

class CategoryListWidget extends ConsumerWidget {
  const CategoryListWidget({super.key});

  static IconData _getCategoryIcon(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('boisson') || lower.contains('jus')) {
      return Icons.local_drink;
    }
    if (lower.contains('pizza')) return Icons.local_pizza;
    if (lower.contains('burger')) return Icons.lunch_dining;
    if (lower.contains('poulet') || lower.contains('viande')) {
      return Icons.set_meal;
    }
    if (lower.contains('poisson')) return Icons.set_meal;
    if (lower.contains('dessert') || lower.contains('patisserie')) {
      return Icons.cake;
    }
    if (lower.contains('salade') || lower.contains('legume')) return Icons.eco;
    if (lower.contains('sandwich')) return Icons.bakery_dining;
    if (lower.contains('petit') || lower.contains('dejeuner')) {
      return Icons.free_breakfast;
    }
    if (lower.contains('africain') || lower.contains('local')) {
      return Icons.restaurant;
    }
    if (lower.contains('grillad')) return Icons.outdoor_grill;
    if (lower.contains('pates') || lower.contains('riz')) {
      return Icons.dinner_dining;
    }
    return Icons.fastfood;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryItem(
                category: category,
                icon: _getCategoryIcon(category.name),
              );
            },
          ),
        );
      },
      loading: () => _buildShimmer(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                ShimmerBox(
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.circular(28),
                ),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: 48,
                  height: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final IconData icon;

  const _CategoryItem({required this.category, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          AnalyticsService.logCategoryTap(categoryName: category.name);
        },
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.primaryColor, size: 26),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                category.name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
