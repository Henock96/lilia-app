import 'package:flutter/material.dart';
import 'package:lilia_app/common_widgets/resolution_par_identifiant.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/features/cart/presentation/cart_mode_conflict_dialog.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/utils/snackbar.dart';
import 'package:lilia_app/features/cart/presentation/product_options_gate.dart';
import 'package:lilia_app/features/home/presentation/widgets/product_stock_widgets.dart';

/// La route porte `/profile/favoris/details/:productId`.
class FavorisDetailPage extends ConsumerWidget {
  const FavorisDetailPage({super.key, required this.productId, this.product});

  final String productId;
  final Product? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResolutionParIdentifiant<Product>(
      dejaLa: product,
      charger: (ref) => ref.watch(productByIdProvider(productId)),
      onRetry: () => ref.invalidate(productByIdProvider(productId)),
      introuvable: 'Produit introuvable',
      rendu: (p) => _FavorisDetailView(product: p),
    );
  }
}

class _FavorisDetailView extends ConsumerStatefulWidget {
  final Product product;

  const _FavorisDetailView({required this.product});

  @override
  ConsumerState<_FavorisDetailView> createState() => _FavorisDetailPageState();
}

class _FavorisDetailPageState extends ConsumerState<_FavorisDetailView> {
  final int _quantity = 1;
  ProductVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    // Même règle que la fiche produit : sélection d'office **uniquement**
    // quand il n'existe qu'un format, et qu'il est vendable. Présélectionner
    // « le seul format encore en stock » parmi plusieurs choisissait à la
    // place du client.
    final variants = widget.product.variants;
    if (variants.length == 1 && variants.single.isInStock) {
      _selectedVariant = variants.single;
    }
  }

  double get _currentPrice {
    if (_selectedVariant != null) {
      return _selectedVariant!.prix * _quantity;
    }
    return widget.product.prixOriginal * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref
        .watch(favoritesProvider)
        .maybeWhen(
          data: (favorites) => favorites.any((p) => p.id == widget.product.id),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          IconButton(
            tooltip: 'Retirer des favoris',
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.black,
            ),
            onPressed: () {
              final notifier = ref.read(favoritesProvider.notifier);
              if (isFavorite) {
                notifier.remove(widget.product);
              } else {
                notifier.add(widget.product);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Hero(
                      tag:
                          'favorite_${widget.product.id}', // Unique tag for favorites
                      child: widget.product.thumbnailUrl != null
                          ? AppCachedImage(
                              imageUrl: widget.product.thumbnailUrl!,
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorIcon: Icons.fastfood,
                            )
                          : Container(
                              height: 250,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.fastfood,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatPrice(_currentPrice),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product.description,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  if (widget.product.variants.isNotEmpty) ...[
                    const Text(
                      'Selectionnez une variante',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    VariantSelector(
                      variants: widget.product.variants,
                      selected: _selectedVariant,
                      onSelected: (variant) =>
                          setState(() => _selectedVariant = variant),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed:
                    !widget.product.hasModifiers &&
                        (widget.product.variants.isEmpty ||
                            _selectedVariant == null ||
                            !_selectedVariant!.isInStock)
                    ? null
                    : () async {
                        // F3-09 — les options se choisissent sur la fiche produit.
                        if (openProductForOptions(context, widget.product)) {
                          return;
                        }
                        // Garanti non nul et vendable par la garde du bouton.
                        final variant = _selectedVariant!;
                        try {
                          // `addToCartSafely` : un conflit « sur commande /
                          // immédiat » ouvre la modale qui propose de vider le
                          // panier, au lieu d'échouer en message d'erreur.
                          final added = await addToCartSafely(
                            context: context,
                            ref: ref,
                            quantity: _quantity,
                            preview: CartItemPreview.fromProduct(
                              widget.product,
                              variant,
                            ),
                          );
                          if (added && context.mounted) {
                            context.showSuccessSnack(
                              '${widget.product.name} a été ajouté au panier.',
                            );
                          }
                        } on CartException catch (e) {
                          if (context.mounted) context.showErrorSnack(e.message);
                        }
                      },
                child: const Text(
                  'Ajouter au panier',
                  // Couleur du thème (`textOnAction`) : le blanc imposé tombait à
                  // 2.84:1 sur l'action orange clair du mode sombre.
                  style: TextStyle(fontSize: 19),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
