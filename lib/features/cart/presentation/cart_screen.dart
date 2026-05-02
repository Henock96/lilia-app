import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/services/analytics_service.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Rafraîchir le panier quand on ouvre l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartControllerProvider.notifier).refresh();
    });
  }

  bool _isClearing = false;

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le panier'),
        content: const Text(
          'Voulez-vous vraiment supprimer tous les articles du panier ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      await ref.read(cartControllerProvider.notifier).clearCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final hasItems =
        cartState.value != null && cartState.value!.items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Mon Panier'),
        actions: [
          if (hasItems)
            _isClearing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _clearCart,
                    icon: const Icon(
                      Icons.delete_sweep,
                      size: 20,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Tout supprimer',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            cartState.when(
              data: (cart) {
                if (cart == null || cart.items.isEmpty) {
                  return Expanded(child: _EmptyCartWithSuggestions());
                }

                final individualItems = cart.individualItems;
                final menuGroups = cart.menuGroups;

                return Expanded(
                  child: ListView(
                    children: [
                      // Menus groupés
                      ...menuGroups.entries.map((entry) {
                        final menuId = entry.key;
                        final groupItems = entry.value;
                        return MenuCartCard(menuId: menuId, items: groupItems);
                      }),
                      // Items individuels
                      ...individualItems.map(
                        (item) => CartItemCard(item: item),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const BuildLoadingState(),
              error: (err, stack) => BuildErrorState(
                err,
                onRetry: () => ref.invalidate(cartControllerProvider),
              ),
            ),
            cartState.value != null && cartState.value!.items.isNotEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 5,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${cartState.value!.totalItems} article(s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cartState.value!.formattedTotalPrice,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () {
                                context.goNamed(
                                  AppRoutes.deliveryOptions.routeName,
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 12.0,
                                ),
                                child: Text(
                                  'Passer la commande',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}

/// Card affichant un menu groupé dans le panier
class MenuCartCard extends ConsumerStatefulWidget {
  final String menuId;
  final List<CartItem> items;

  const MenuCartCard({super.key, required this.menuId, required this.items});

  @override
  ConsumerState<MenuCartCard> createState() => _MenuCartCardState();
}

class _MenuCartCardState extends ConsumerState<MenuCartCard> {
  bool _isLoading = false;

  MenuInfo? get _menuInfo =>
      widget.items.isNotEmpty ? widget.items.first.menu : null;
  int get _quantity =>
      widget.items.isNotEmpty ? widget.items.first.quantite : 0;

  Future<void> _updateQuantity(int newQuantity) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .updateMenuQuantity(menuId: widget.menuId, quantity: newQuantity);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMenu() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .removeMenu(menuId: widget.menuId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuInfo = _menuInfo;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: _isLoading ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du menu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menuInfo?.nom ?? 'Menu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Text(
                          '${menuInfo?.prix.toStringAsFixed(0) ?? '0'} FCFA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Liste des produits inclus
            ...widget.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: item.product.imageUrl != null
                          ? Image.network(
                              item.product.imageUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.fastfood,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.fastfood,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.nom,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.variant.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Contrôles quantité / suppression
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_quantity > 1)
                    Expanded(
                      child: Text(
                        'Sous-total: ${(menuInfo!.prix * _quantity).toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _isLoading
                          ? null
                          : () => _updateQuantity(_quantity - 1),
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _isLoading
                          ? null
                          : () => _updateQuantity(_quantity + 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isLoading ? null : _removeMenu,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartItemCard extends ConsumerStatefulWidget {
  final CartItem item;

  const CartItemCard({super.key, required this.item});

  @override
  ConsumerState<CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends ConsumerState<CartItemCard> {
  bool _isLoading = false;

  Future<void> _updateQuantity(int newQuantity) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .updateItemQuantity(
            cartItemId: widget.item.id,
            quantity: newQuantity,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeItem() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .removeItem(cartItemId: widget.item.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Opacity(
        opacity: _isLoading ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.item.product.imageUrl != null
                    ? Image.network(
                        widget.item.product.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.fastfood,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.fastfood, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.product.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.variant.label,
                      style: const TextStyle(color: Colors.black, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.item.variant.prix} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (widget.item.quantite > 1)
                      Text(
                        'Sous-total: ${(widget.item.variant.prix * widget.item.quantite)} FCFA',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _isLoading
                          ? null
                          : () => _updateQuantity(widget.item.quantite - 1),
                    ),
                    Text(
                      widget.item.quantite.toString(),
                      style: const TextStyle(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _isLoading
                          ? null
                          : () => _updateQuantity(widget.item.quantite + 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isLoading ? null : _removeItem,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ PANIER VIDE AVEC SUGGESTIONS ============

class _EmptyCartWithSuggestions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final popularAsync = ref.watch(popularProductsProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Iconsax.shopping_bag, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Votre panier est vide',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des plats pour commencer',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.goNamed(AppRoutes.home.routeName),
            icon: const Icon(Icons.explore, size: 20),
            label: const Text(
              'Explorer les plats',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Section plats populaires
          popularAsync.when(
            data: (products) {
              if (products.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 20,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Plats populaires',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...products
                      .take(5)
                      .map((product) => _SuggestionTile(product: product)),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(color: theme.primaryColor),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SuggestionTile extends ConsumerWidget {
  final Product product;

  const _SuggestionTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAvailable = product.isAvailable;

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: InkWell(
          onTap: () {
            context.pushNamed(
              AppRoutes.productDetail.routeName,
              extra: product,
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.restaurantName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.restaurantName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${product.displayPrice.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAvailable)
                  GestureDetector(
                    onTap: () => _handleAddToCart(context, ref),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Epuise',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[200],
      child: const Icon(Icons.fastfood, size: 28, color: Colors.grey),
    );
  }

  void _handleAddToCart(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour ajouter au panier'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (product.variants.length > 1) {
      _showVariantBottomSheet(context, ref);
    } else if (product.variants.isNotEmpty) {
      _addToCart(context, ref, product.variants.first);
    }
  }

  void _addToCart(BuildContext context, WidgetRef ref, ProductVariant variant) {
    AnalyticsService.logAddToCartFromHome(
      productId: product.id,
      productName: product.name,
      source: 'empty_cart_suggestion',
      price: variant.prix,
    );
    ref
        .read(cartControllerProvider.notifier)
        .addItem(variantId: variant.id)
        .then((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${product.name} ajoute au panier'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        })
        .catchError((e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
  }

  void _showVariantBottomSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choisir une option',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...product.variants.map((variant) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _addToCart(context, ref, variant);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          variant.label,
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${variant.prix.toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
