import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/features/commandes/presentation/fullscreen_tracking_screen.dart';
import 'package:lilia_app/features/commandes/presentation/progress_step.dart';
import 'package:lilia_app/features/commandes/presentation/status_info.dart';
import 'package:lilia_app/models/order.dart';

import '../../../models/order_item.dart';
import '../../cart/application/cart_controller.dart';
import '../data/order_controller.dart';

class OrderDetailPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(userOrdersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Détails de la commande',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Iconsax.share), onPressed: () {}),
        ],
      ),
      body: orderAsyncValue.when(
        data: (orders) {
          final order = orders.firstWhere(
            (o) => o.id == orderId,
            orElse: () => throw Exception('Commande non trouvée !'),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header avec statut
                _buildHeaderCard(context, order),

                const SizedBox(height: 16),

                // Barre de progression pour les commandes en cours
                if (order.status != OrderStatus.livrer &&
                    order.status != OrderStatus.annuler)
                  _buildProgressCard(context, order),

                if (order.status != OrderStatus.livrer &&
                    order.status != OrderStatus.annuler)
                  const SizedBox(height: 16),

                // Bouton de tracking temps réel quand la commande est en route
                if (order.status == OrderStatus.enRoute) ...[
                  _buildTrackingButton(context, order.id),
                  const SizedBox(height: 16),
                ],

                // Section Restaurant
                _buildRestaurantCard(context, order),

                const SizedBox(height: 16),

                // Section Articles
                _buildItemsCard(context, order),

                const SizedBox(height: 16),

                // Section Livraison
                _buildDeliveryCard(context, order),

                const SizedBox(height: 16),

                // Section Sommaire
                _buildSummaryCard(context, order),

                const SizedBox(height: 24),

                // Bouton Annuler pour les commandes en attente
                if (order.status == OrderStatus.enAttente)
                  _buildCancelButton(context, ref, order.id),

                // Bouton Commander à nouveau pour les commandes livrées ou annulées
                if (order.status == OrderStatus.livrer ||
                    order.status == OrderStatus.annuler)
                  _buildReorderButton(context, ref, order.id),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
        error: (err, stack) => BuildErrorState(
          err,
          onRetry: () => ref.invalidate(userOrdersProvider),
        ),
      ),
    );
  }

  Widget _buildTrackingButton(BuildContext context, String orderId) {
    //final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullscreenTrackingScreen(orderId: orderId),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade600, Colors.indigo.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delivery_dining,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suivre le livreur en direct',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Position mise à jour en temps réel',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Order order) {
    final cs = Theme.of(context).colorScheme;
    final formattedDate = DateFormat(
      'dd MMM yyyy',
      'fr_FR',
    ).format(order.createdAt);
    final formattedTime = DateFormat('HH:mm').format(order.createdAt);
    final statusInfo = _getStatusInfo(order.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commande',
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusInfo.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(statusInfo.icon, color: statusInfo.color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusInfo.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusInfo.color,
                        ),
                      ),
                      Text(
                        statusInfo.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusInfo.color.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Iconsax.calendar, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Icon(Iconsax.clock, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    final info = _getStatusInfo(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 14, color: info.color),
          const SizedBox(width: 6),
          Text(
            info.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, Order order) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.routing, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              const Text(
                'Suivi de commande',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _OrderProgressStepper(status: order.status),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(BuildContext context, Order order) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.shop, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              const Text(
                'Restaurant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: order.restaurant.imageUrl != null
                      ? Image.network(
                          order.restaurant.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, stackTrace) =>
                              _buildPlaceholderImage(ctx),
                        )
                      : _buildPlaceholderImage(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.restaurant.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.location,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.restaurant.adresse ??
                                'Adresse non disponible',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, color: cs.outline, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context, Order order) {
    final cs = Theme.of(context).colorScheme;
    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantite,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.bag_2, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Text(
                    'Articles commandés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$itemCount article${itemCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...order.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _OrderItemCard(item: item),
                if (index < order.items.length - 1)
                  Divider(height: 24, color: cs.outline.withValues(alpha: 0.3)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, Order order) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                order.isDelivery ? Iconsax.truck_fast : Iconsax.shop,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                order.isDelivery ? 'Livraison' : 'Retrait en magasin',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: order.isDelivery ? Colors.blue[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  order.isDelivery ? Iconsax.location : Iconsax.shop,
                  color: order.isDelivery
                      ? Colors.blue[400]
                      : Colors.orange[400],
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.isDelivery
                          ? 'Adresse de livraison'
                          : 'Adresse du restaurant',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.isDelivery
                          ? (order.deliveryAddress ?? 'Adresse non spécifiée')
                          : (order.restaurant.adresse ??
                                'Adresse non disponible'),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Order order) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.receipt_1, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              const Text(
                'Récapitulatif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(context, 'Sous-total', order.subTotal),
          const SizedBox(height: 8),
          if (order.isDelivery) ...[
            _buildSummaryRow(
              context,
              'Frais de livraison',
              order.deliveryFee,
            ),
            const SizedBox(height: 8),
          ],
          _buildSummaryRow(context, 'Frais de service (8%)', order.serviceFee),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              context,
              'Réduction',
              -order.discountAmount,
              isDiscount: true,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: cs.outline.withValues(alpha: 0.3)),
          ),
          _buildSummaryRow(context, 'Total', order.total, isTotal: true),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _getPaymentIcon(order.paymentMethod),
                  color: cs.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Méthode de paiement',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getDisplayStatusPaiement(order.paymentMethod),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    double value, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final valueColor = isTotal
        ? cs.primary
        : isDiscount
            ? Colors.green.shade700
            : cs.onSurface;
    final formatted = isDiscount
        ? '${value.toStringAsFixed(0)} FCFA'
        : '${value.toStringAsFixed(0)} FCFA';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (isDiscount) ...[
              Icon(Icons.local_offer, size: 14, color: Colors.green.shade700),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal
                    ? cs.onSurface
                    : isDiscount
                        ? Colors.green.shade700
                        : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          formatted,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _showCancelConfirmationDialog(context, ref, orderId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.close_circle, color: Colors.red[400]),
            const SizedBox(width: 10),
            Text(
              'Annuler la commande',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderButton(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _handleReorder(context, ref, orderId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.refresh, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Commander à nouveau',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReorder(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ref
          .read(cartControllerProvider.notifier)
          .reorder(orderId: orderId);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      final summary = result['summary'] as Map<String, dynamic>? ?? {};
      final totalAdded = summary['totalAdded'] ?? result['totalAdded'] ?? 0;
      final totalUnavailable =
          summary['totalUnavailable'] ?? result['totalUnavailable'] ?? 0;

      if (totalAdded > 0) {
        String message =
            '$totalAdded article${totalAdded > 1 ? 's' : ''} ajouté${totalAdded > 1 ? 's' : ''} au panier';
        if (totalUnavailable > 0) {
          message +=
              '\n$totalUnavailable article${totalUnavailable > 1 ? 's' : ''} indisponible${totalUnavailable > 1 ? 's' : ''}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Voir le panier',
              textColor: Colors.white,
              onPressed: () {
                context.go('/cart');
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Aucun article disponible pour cette commande'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      String errorMessage = 'Erreur lors de la recommande';
      if (e.toString().contains('autre restaurant')) {
        errorMessage =
            'Votre panier contient des articles d\'un autre restaurant. Videz-le d\'abord.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(child: Icon(Iconsax.shop, size: 30, color: cs.outline)),
    );
  }

  void _showCancelConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Annuler la commande ?'),
            ],
          ),
          content: const Text(
            'Cette action est irréversible. Êtes-vous sûr de vouloir annuler cette commande ?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Non, garder'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Oui, annuler'),
              onPressed: () async {
                Navigator.of(context).pop();
                if (!context.mounted) return;
                try {
                  await ref
                      .read(userOrdersProvider.notifier)
                      .cancelOrder(orderId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Commande annulée avec succès'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  StatusInfo _getStatusInfo(OrderStatus status) {
    switch (status) {
      case OrderStatus.enAttente:
        return StatusInfo(
          label: 'En attente',
          description: 'Votre commande est en attente de confirmation',
          color: Colors.orange,
          icon: Iconsax.timer_1,
        );
      case OrderStatus.payer:
        return StatusInfo(
          label: 'Payée',
          description: 'Votre paiement a été confirmé',
          color: Colors.purple,
          icon: Iconsax.card_tick,
        );
      case OrderStatus.enPreparation:
        return StatusInfo(
          label: 'En préparation',
          description: 'Le restaurant prépare votre commande',
          color: Colors.blue,
          icon: Iconsax.cake,
        );
      case OrderStatus.pret:
        return StatusInfo(
          label: 'Prête',
          description: 'Votre commande est prête pour la livraison',
          color: Colors.green,
          icon: Iconsax.tick_circle,
        );
      case OrderStatus.enRoute:
        return StatusInfo(
          label: 'En route',
          description: 'Votre livreur est en chemin vers vous',
          color: Colors.indigo,
          icon: Iconsax.truck_fast,
        );
      case OrderStatus.livrer:
        return StatusInfo(
          label: 'Livrée',
          description: 'Votre commande a été livrée',
          color: Colors.teal,
          icon: Iconsax.verify,
        );
      case OrderStatus.annuler:
        return StatusInfo(
          label: 'Annulée',
          description: 'Cette commande a été annulée',
          color: Colors.red,
          icon: Iconsax.close_circle,
        );
      default:
        return StatusInfo(
          label: 'Inconnu',
          description: 'Statut inconnu',
          color: Colors.grey,
          icon: Iconsax.info_circle,
        );
    }
  }

  String _getDisplayStatusPaiement(String paymentMethod) {
    switch (paymentMethod) {
      case 'MTN_MOMO':
        return 'MTN Mobile Money';
      case 'AIRTEL_MONEY':
        return 'Airtel Money';
      default:
        return paymentMethod;
    }
  }

  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod) {
      case 'AIRTEL_MONEY':
        return Iconsax.mobile;
      default:
        return Iconsax.mobile;
    }
  }
}

class _OrderItemCard extends StatelessWidget {
  final OrderItem item;

  const _OrderItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String itemImageUrl = item.product.imageUrl ?? '';

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 70,
            height: 70,
            child: itemImageUrl.isNotEmpty
                ? Image.network(
                    itemImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, error, stackTrace) =>
                        _buildPlaceholderImage(ctx),
                  )
                : _buildPlaceholderImage(context),
          ),
        ),
        const SizedBox(width: 14),
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
                item.variant,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'x${item.quantite}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${(item.prix * item.quantite).toStringAsFixed(0)} FCFA',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(child: Icon(Iconsax.gallery, size: 28, color: cs.outline)),
    );
  }
}

class _OrderProgressStepper extends StatelessWidget {
  final OrderStatus status;

  const _OrderProgressStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = [
      ProgressStep(
        icon: Iconsax.tick_circle,
        label: 'Confirmée',
        isCompleted: status != OrderStatus.enAttente,
        isCurrent: status == OrderStatus.enAttente,
      ),
      ProgressStep(
        icon: Iconsax.cake,
        label: 'En préparation',
        isCompleted:
            status == OrderStatus.pret ||
            status == OrderStatus.enRoute ||
            status == OrderStatus.livrer,
        isCurrent: status == OrderStatus.enPreparation,
      ),
      ProgressStep(
        icon: Iconsax.box_tick,
        label: 'Prête',
        isCompleted:
            status == OrderStatus.enRoute || status == OrderStatus.livrer,
        isCurrent: status == OrderStatus.pret,
      ),
      ProgressStep(
        icon: Iconsax.truck_fast,
        label: 'En route',
        isCompleted: status == OrderStatus.livrer,
        isCurrent: status == OrderStatus.enRoute,
      ),
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isCompleted =
              steps[stepIndex].isCompleted || steps[stepIndex].isCurrent;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green
                    : cs.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        } else {
          final step = steps[index ~/ 2];
          return _buildStepItem(context, step);
        }
      }),
    );
  }

  Widget _buildStepItem(BuildContext context, ProgressStep step) {
    final cs = Theme.of(context).colorScheme;
    final color = step.isCompleted || step.isCurrent
        ? Colors.green
        : cs.outline;

    return Column(
      children: [
        Container(
          width: step.isCurrent ? 44 : 36,
          height: step.isCurrent ? 44 : 36,
          decoration: BoxDecoration(
            color: step.isCompleted || step.isCurrent
                ? Colors.green.withValues(alpha: 0.1)
                : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: step.isCurrent
                ? Border.all(color: Colors.green, width: 2)
                : null,
          ),
          child: Icon(step.icon, size: step.isCurrent ? 22 : 18, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: step.isCurrent ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
