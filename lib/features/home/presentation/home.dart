import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/presentation/notifications_history_screen.dart';

import '../../../models/produit.dart';
import '../../../routing/app_route_enum.dart';
import '../data/remote/restaurant_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ID du restaurant à récupérer
    const String restaurantId = 'cmd9iay8y0000o4hjhi3w46z8';

    final restaurantAsyncValue =
        ref.watch(restaurantControllerProvider(restaurantId));
    final cartAsyncValue = ref.watch(cartControllerProvider);
    final notificationHistory = ref.watch(notificationHistoryProvider);

    // Écouteur pour les effets de bord (side effects) comme les SnackBars.
    // Ne provoque pas de reconstruction du widget.
    ref.listen(notificationStreamProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final notification = next.value!;
        ref.read(notificationHistoryProvider.notifier).addNotification(notification);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nouvelle notification: ${notification.body}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Lilia Food'),
        actions: [
          notificationHistory.when(
            data: (notifications) => Badge(
              label: Text(notifications.length.toString()),
              isLabelVisible: notifications.isNotEmpty,
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none, color: Colors.black),
              ),
            ),
            loading: () => IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none, color: Colors.black),
            ),
            error: (_, __) => IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined, color: Colors.red),
            ),
          ),
        ],
      ),
      floatingActionButton: cartAsyncValue.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => context.goNamed(AppRoutes.cart.routeName),
            child: Badge(
              label: Text(cart.totalItems.toString()),
              child: const Icon(Icons.shopping_cart),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(cartControllerProvider.future),
        child: restaurantAsyncValue.when(
          data: (restaurant) {
            // --- Logique de groupement sécurisée ---
            if (restaurant == null || restaurant.products == null) {
              return const Center(child: Text("Ce restaurant n'a pas de produits."));
            }

            Map<String, List<Product>> productsByCategory = {};
            List<Product> uncategorizedProducts = [];

            for (var product in restaurant.products) {
              final categoryName = product.category?.name;
              if (categoryName != null && categoryName.isNotEmpty) {
                if (!productsByCategory.containsKey(categoryName)) {
                  productsByCategory[categoryName] = [];
                }
                productsByCategory[categoryName]!.add(product);
              } else {
                uncategorizedProducts.add(product);
              }
            }

            List<Widget> categoryWidgets = [];
            productsByCategory.forEach((categoryName, products) {
              categoryWidgets.add(CategorySection(
                categoryName: categoryName,
                products: products,
              ));
            });

            if (uncategorizedProducts.isNotEmpty) {
              categoryWidgets.add(CategorySection(
                categoryName: 'Autres',
                products: uncategorizedProducts,
              ));
            }
            // --- Fin de la logique de groupement ---

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Adresse: ${restaurant.address}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.black),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 20,
                            left: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Commandez maintenant',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'Et obtenez une livraison gratuite',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Passez la commande', style: TextStyle(color: Colors.black)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Nos Catégories',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...categoryWidgets,
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
          loading: () => const BuildLoadingState(),
          error: (err, stack) => BuildErrorState(err),
        ),
      ),
    );
  }
}

// Widget pour une section de catégorie
class CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Product> products;

  const CategorySection({
    super.key,
    required this.categoryName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...products.map((product) {
            return GestureDetector(
              onTap: () {
                context.goNamed(
                  AppRoutes.productDetail.routeName,
                  extra: product,
                );
              },
              child: ProductCard(product: product),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  double getDisplayPrice() {
    if (product.variants.isNotEmpty) {
      return product.variants.first.prix;
    }
    return product.prixOriginal;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(product.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${getDisplayPrice().toStringAsFixed(1)} FCFA',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: Theme.of(context).primaryColor, size: 30),
              onPressed: () {
                if (product.variants.isNotEmpty) {
                  final variantId = product.variants.first.id;
                  ref.read(cartControllerProvider.notifier).addItem(variantId: variantId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} a été ajouté au panier.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ce produit n\'a pas de variante sélectionnable.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}