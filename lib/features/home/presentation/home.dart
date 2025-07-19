import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';

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

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Lilia App'),
        actions: [
          IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.black,
              ))
        ],
      ),
      floatingActionButton: cartAsyncValue.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () {
              context.push(AppRoutes.cart.routeName);
            },
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
        onRefresh: ()=> ref.refresh(cartControllerProvider.future),
        child: restaurantAsyncValue.when(
          data: (restaurant) {
            // Filtrer et grouper les produits par catégorie
            Map<String, List<Product>> productsByCategory = {};
            for (var product in restaurant.products) {
              if (product.category != null) {
                final categoryName = product.category!.name;
                if (!productsByCategory.containsKey(categoryName)) {
                  productsByCategory[categoryName] = [];
                }
                productsByCategory[categoryName]!.add(product);
              }
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Adresse: ${restaurant.address}',
                          // Utilisez 'address'
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
                        /*image: const DecorationImage(
                            image: AssetImage(
                                'assets/images/promo_banner.png'),
                            // Assurez-vous d'avoir cette image
                            fit: BoxFit.cover,
                          ),*/
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
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'Et obtenez une livraison gratuite',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    // Action pour commander maintenant
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Passez la commande',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: const Text(
                      'Nos Catégories',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Affichage des produits par catégorie en colonne
                  ...productsByCategory.entries.map((entry) {
                    final categoryName = entry.key;
                    final productsInCategory = entry.value;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: productsInCategory.map((product) {
                              return GestureDetector(
                                  onTap: () {
                                    // NAVIGUER AVEC GOROUTER
                                    context.goNamed(
                                      AppRoutes.productDetail.routeName,
                                      extra:
                                          product, // Passez l'objet Product entier ici
                                    );
                                  },
                                  child: ProductCard(product: product));
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
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

class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  // Fonction pour obtenir le prix à afficher
  // Si des variants existent, affiche le prix du premier variant, sinon le prix original
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

                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Afficher le prix en tenant compte des variants
                    '${getDisplayPrice().toStringAsFixed(1)} FCFA',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.teal, size: 30,),
              onPressed: () {
                if (product.variants.isNotEmpty) {
                  final variantId = product.variants.first.id;
                  ref
                      .read(cartControllerProvider.notifier)
                      .addItem(variantId: variantId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} a été ajouté au panier.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Gérer le cas où il n'y a pas de variante (si c'est possible dans votre logique)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ce produit n\'a pas de variante sélectionnable.'),
                      duration: Duration(seconds: 2),
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

