import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';

import '../../../models/produit.dart';

class FavorisPage extends ConsumerWidget {
  const FavorisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris'),
        centerTitle: true,
        elevation: 0,
      ),
      body: favorites.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/fav.jpg", width: 150, height: 150),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 18.0,
                      top: 0,
                      right: 18.0,
                    ),
                    child: Text(
                      'Vous avez aucun article en favoris pour le moment !',
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ProductCardFavoris(product: product),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Erreur: $error')),
      ),
    );
  }
}

class ProductCardFavoris extends ConsumerWidget {
  final Product product;

  const ProductCardFavoris({super.key, required this.product});

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
    final isFavorite = ref
        .watch(favoritesProvider)
        .maybeWhen(
          data: (favorites) => favorites.any((p) => p.id == product.id),
          orElse: () => false,
        );
    return GestureDetector(
      onTap: () {
        context.pushNamed(AppRoutes.favoriteDetail.routeName, extra: product);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Hero(
                tag: 'favorite_${product.id}', // Unique tag for favorites
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                    image: product.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(product.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product.imageUrl == null
                      ? const Center(
                          child: Icon(
                            Icons.fastfood,
                            size: 40,
                            color: Colors.grey,
                          ),
                        )
                      : null,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.black,
                ),
                onPressed: () {
                  final notifier = ref.read(favoritesProvider.notifier);
                  if (isFavorite) {
                    notifier.remove(product);
                  } else {
                    notifier.add(product);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
