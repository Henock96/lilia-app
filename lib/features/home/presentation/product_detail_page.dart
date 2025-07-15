import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';

import '../../../models/produit.dart';
import '../../cart/application/cart_controller.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _quantity = 1; // Quantité sélectionnée
  ProductVariant? _selectedVariant; // Variant sélectionné

  @override
  void initState() {
    super.initState();
    // Sélectionne le premier variant par défaut si disponible
    if (widget.product.variants.isNotEmpty) {
      _selectedVariant = widget.product.variants.first;
    }
  }

  // Calcule le prix total en fonction de la quantité et du variant sélectionné
  double get _currentPrice {
    if (_selectedVariant != null) {
      return _selectedVariant!.prix * _quantity;
    }
    return widget.product.prixOriginal * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(favoritesProvider).maybeWhen(
          data: (favorites) => favorites.any((p) => p.id == widget.product.id),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.product.name),
        actions: [
          IconButton(
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
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {
              // Action de recherche
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
                      tag: widget.product.id,
                      child: Image.network(
                        widget.product.imageUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                if (_quantity > 1) _quantity--;
                              });
                            },
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.green),
                            onPressed: () {
                              setState(() {
                                _quantity++;
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.delete_outline,
                              color: Colors.red),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_currentPrice.toStringAsFixed(2)} FCFA',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const Text('4.8', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product.description,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (widget.product.variants.isNotEmpty) ...[
                    const Text(
                      'Selectionnez une variante de ce produit',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: widget.product.variants.map((variant) {
                        final isSelected = _selectedVariant?.id == variant.id;
                        return ChoiceChip(
                          label: Text(
                            '${variant.label} (${variant.prix.toStringAsFixed(2)} FCFA)',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.redAccent,
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.redAccent
                                  : Colors.transparent,
                            ),
                          ),
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
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedVariant == null &&
                      widget.product.variants.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a variant!')),
                    );
                    return;
                  }
                  print(
                      'Adding ${widget.product.name} (Variant: ${_selectedVariant?.label ?? "N/A"}, Qty: $_quantity) to cart.');
                  /*ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${_quantity}x ${widget.product.name} added to cart!')),
                  );*/
                  final variantId = _selectedVariant!.id;
                  ref
                      .read(cartControllerProvider.notifier)
                      .addItem(variantId: variantId, quantity: _quantity);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.product.name} a été ajouté au panier.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Ajouter au panier',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
