import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

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

  @override
  Widget build(BuildContext context) {
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

              final individualItems = cart.individualItems;
              final menuGroups = cart.menuGroups;

              return Expanded(
                child: ListView(
                  children: [
                    // Menus groupés
                    ...menuGroups.entries.map((entry) {
                      final menuId = entry.key;
                      final groupItems = entry.value;
                      return MenuCartCard(
                        menuId: menuId,
                        items: groupItems,
                      );
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
          if (cartState.value == null || cartState.value!.items.isEmpty)
            const Spacer(),
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
                              context.goNamed(AppRoutes.deliveryOptions.routeName);
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
    );
  }
}

/// Card affichant un menu groupé dans le panier
class MenuCartCard extends ConsumerStatefulWidget {
  final String menuId;
  final List<CartItem> items;

  const MenuCartCard({
    super.key,
    required this.menuId,
    required this.items,
  });

  @override
  ConsumerState<MenuCartCard> createState() => _MenuCartCardState();
}

class _MenuCartCardState extends ConsumerState<MenuCartCard> {
  bool _isLoading = false;

  MenuInfo? get _menuInfo => widget.items.isNotEmpty ? widget.items.first.menu : null;
  int get _quantity => widget.items.isNotEmpty ? widget.items.first.quantite : 0;

  Future<void> _updateQuantity(int newQuantity) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(cartControllerProvider.notifier).updateMenuQuantity(
            menuId: widget.menuId,
            quantity: newQuantity,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
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
      await ref.read(cartControllerProvider.notifier).removeMenu(
            menuId: widget.menuId,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
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
            ...widget.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                    child: const Icon(Icons.fastfood,
                                        size: 18, color: Colors.grey),
                                  );
                                },
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.fastfood,
                                    size: 18, color: Colors.grey),
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
                )),
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
                    Text(
                      '$_quantity',
                      style: const TextStyle(fontSize: 18),
                    ),
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
      await ref.read(cartControllerProvider.notifier).updateItemQuantity(
            cartItemId: widget.item.id,
            quantity: newQuantity,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
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
      await ref.read(cartControllerProvider.notifier).removeItem(
            cartItemId: widget.item.id,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
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
                            child: const Icon(Icons.fastfood, color: Colors.grey),
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
