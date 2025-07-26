import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Panier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: Column(
        children: [
          cartState.when(
            data: (cart) {
              if (cart == null || cart.items.isEmpty) {
                return const Center(
                  child: Text('Votre panier est vide.'),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erreur: $err')),
          ),
          Spacer(),
          cartState.valueOrNull != null &&
              cartState.value!.items.isNotEmpty ?
            Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${cartState.value!.totalPrice.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w400),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.push(AppRoutes.checkout.path);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: const Text('Passer la commande',style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w400),),
                  ),
                )
              ],
            ),
          ) : Container(),
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.nom,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(item.variant.label,
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  Text(
                    '${item.variant.prix.toStringAsFixed(0)} FCFA',
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
                    ref.read(cartControllerProvider.notifier).updateItemQuantity(
                          cartItemId: item.id,
                          quantity: item.quantite - 1,
                        );
                  },
                ),
                Text(item.quantite.toString(),
                    style: const TextStyle(fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    ref.read(cartControllerProvider.notifier).updateItemQuantity(
                          cartItemId: item.id,
                          quantity: item.quantite + 1,
                        );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref.read(cartControllerProvider.notifier).removeItem(cartItemId: item.id);
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
