import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Mon Panier')),
      body: Column(
        children: [
          cartState.when(
            data: (cart) {
              if (cart == null || cart.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 200),
                      Icon(
                        Iconsax.shopping_bag,
                        size: 100,
                        color: Colors.black,
                      ),
                      Text(
                        'Votre Panier est vide !',
                        style: TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            Theme.of(context).primaryColor,
                          ),
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                          ),
                        ),
                        onPressed: () {
                          context.goNamed(AppRoutes.home.routeName);
                        },
                        child: Text(
                          'Commencer vos achats',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: cart.items.length,
                itemBuilder: (context, index) {
                  final item = cart.items[index];
                  return CartItemCard(item: item);
                },
              );
            },
            loading: () => const BuildLoadingState(),
            error: (err, stack) => BuildErrorState(err),
          ),
          Spacer(),
          cartState.valueOrNull != null && cartState.value!.items.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${cartState.value!.totalPrice.toStringAsFixed(1)} FCFA',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          context.goNamed(AppRoutes.checkout.routeName);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 10.0,
                            right: 10.0,
                          ),
                          child: const Text(
                            'Passer la commande',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}

class CartItemCard extends ConsumerWidget {
  final CartItem item;

  const CartItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Image.network(
              item.product.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.variant.label,
                    style: const TextStyle(color: Colors.black, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.variant.prix.toStringAsFixed(1)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    ref
                        .read(cartControllerProvider.notifier)
                        .updateItemQuantity(
                          cartItemId: item.id,
                          quantity: item.quantite - 1,
                        );
                  },
                ),
                Text(
                  item.quantite.toString(),
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    ref
                        .read(cartControllerProvider.notifier)
                        .updateItemQuantity(
                          cartItemId: item.id,
                          quantity: item.quantite + 1,
                        );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref
                        .read(cartControllerProvider.notifier)
                        .removeItem(cartItemId: item.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
