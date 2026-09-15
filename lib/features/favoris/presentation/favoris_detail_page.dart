import 'package:flutter/material.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/utils/snackbar.dart';

class FavorisDetailPage extends ConsumerStatefulWidget {
  final Product product;

  const FavorisDetailPage({super.key, required this.product});

  @override
  ConsumerState<FavorisDetailPage> createState() => _FavorisDetailPageState();
}

class _FavorisDetailPageState extends ConsumerState<FavorisDetailPage> {
  final int _quantity = 1;
  ProductVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      _selectedVariant = widget.product.variants.first;
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
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: widget.product.variants.map((variant) {
                        final isSelected = _selectedVariant?.id == variant.id;
                        return ChoiceChip(
                          label: Text(
                            '${variant.displayLabel} (${formatPrice(variant.prix)})',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Theme.of(context).primaryColor,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedVariant = variant;
                              });
                            }
                          },
                        );
                      }).toList(),
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
                onPressed: () {
                  if (_selectedVariant == null &&
                      widget.product.variants.isNotEmpty) {
                    context.showSnack('Veuillez sélectionner une variante!');
                    return;
                  }
                  try {
                    ref
                        .read(cartControllerProvider.notifier)
                        .addItem(
                          variantId: _selectedVariant!.id,
                          quantity: _quantity,
                          preview: CartItemPreview.fromProduct(
                            widget.product,
                            _selectedVariant!,
                          ),
                        );
                    context.showSnack(
                      '${widget.product.name} a été ajouté au panier.',
                    );
                  } on CartException catch (e) {
                    context.showErrorSnack(e.message);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text(
                  'Ajouter au panier',
                  style: TextStyle(color: Colors.white, fontSize: 19),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
