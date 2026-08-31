import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/features/commandes/presentation/fullscreen_tracking_screen.dart';
import 'package:lilia_app/features/commandes/presentation/progress_step.dart';
import 'package:lilia_app/features/commandes/presentation/status_info.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/payments/presentation/payment_pending_args.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

import '../../../models/order_item.dart';
import '../../cart/application/cart_controller.dart';
import '../data/order_controller.dart';
import '../data/order_repository.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';
import '../../reviews/presentation/widgets/rate_driver_sheet.dart';
import '../data/delivery_tracking_repository.dart';
import '../../../services/notification_router.dart';
import '../../notifications/application/notification_providers.dart';

/// Statuts pour lesquels le reçu PDF est téléchargeable (payée, non annulée).
const _receiptStatuses = <OrderStatus>{
  OrderStatus.payer,
  OrderStatus.enPreparation,
  OrderStatus.pret,
  OrderStatus.enRoute,
  OrderStatus.livrer,
};

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
          tooltip: 'Retour',
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
          // Recherche null-safe : ne JAMAIS throw pendant build (sinon écran
          // rouge). La commande peut être absente de la liste paginée si on
          // arrive ici via notification / deep-link.
          final matches = orders.where((o) => o.id == orderId);
          if (matches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Iconsax.receipt_search,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Commande introuvable',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cette commande n\'est plus disponible ou a été retirée de votre liste.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retour'),
                    ),
                  ],
                ),
              ),
            );
          }
          final order = matches.first;

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

                // Reçu PDF : disponible une fois la commande payée (non annulée)
                if (_receiptStatuses.contains(order.status)) ...[
                  _ReceiptButton(orderId: order.id),
                  const SizedBox(height: 16),
                ],

                // Reprise du paiement — le trou que la bannière
                // `retryPayment` promettait de combler en renvoyant vers « le
                // bouton de paiement ci-dessus », qui n'existait pas. Une
                // commande dont le paiement avait échoué était un cul-de-sac :
                // il fallait la repasser entièrement.
                if (order.status == OrderStatus.enAttente) ...[
                  _PayNowButton(order: order),
                  const SizedBox(height: 12),
                ],

                // Bouton Annuler pour les commandes en attente
                if (order.status == OrderStatus.enAttente)
                  _buildCancelButton(context, ref, order.id),

                // Notation du livreur — uniquement après livraison effective.
                if (order.status == OrderStatus.livrer) ...[
                  _RateDriverCard(orderId: order.id),
                  const SizedBox(height: 16),
                ],

                // Suite proposée par la dernière notification reçue
                // (reprendre un paiement, comprendre un incident). Sans ça,
                // le client arrivait sur l'écran sans savoir quoi faire.
                _NotificationIntentBanner(orderId: order.id),

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
        MaterialPageRoute<void>(
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
          // Précision sur l'étape livreur : le stepper est basé sur le statut
          // de la COMMANDE, qui reste « Prête » tant que le livreur n'a pas
          // récupéré le repas. Sans cette ligne, le client ne saurait pas
          // qu'un livreur est déjà en route vers le restaurant.
          _DeliveryProgressHint(orderId: order.id),
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
                      ? AppCachedImage(
                          imageUrl: order.restaurant.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: _buildPlaceholderImage(context),
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
            _buildSummaryRow(context, 'Frais de livraison', order.deliveryFee),
            const SizedBox(height: 8),
          ],
          _buildSummaryRow(context, 'Frais de service', order.serviceFee),
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
    final formatted = isDiscount ? formatPrice(value) : formatPrice(value);
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
    showDialog<void>(
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
      // Typés explicitement : ces valeurs viennent d'un Map<String, dynamic>
      // et servaient directement de condition (`totalAdded > 0`).
      final int totalAdded =
          (summary['totalAdded'] as int?) ??
          (result['totalAdded'] as int?) ??
          0;
      final int totalUnavailable =
          (summary['totalUnavailable'] as int?) ??
          (result['totalUnavailable'] as int?) ??
          0;

      if (totalAdded > 0) {
        String message =
            '$totalAdded article${totalAdded > 1 ? 's' : ''} ajouté${totalAdded > 1 ? 's' : ''} au panier';
        if (totalUnavailable > 0) {
          message +=
              '\n$totalUnavailable article${totalUnavailable > 1 ? 's' : ''} indisponible${totalUnavailable > 1 ? 's' : ''}';
        }

        context.showSnack(
          message,
          type: SnackType.success,
          action: SnackBarAction(
            label: 'Voir le panier',
            textColor: Colors.white,
            onPressed: () => context.go('/cart'),
          ),
        );
      } else {
        context.showErrorSnack('Aucun article disponible pour cette commande');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      String errorMessage = 'Erreur lors de la recommande';
      if (e.toString().contains('autre restaurant')) {
        errorMessage =
            'Votre panier contient des articles d\'un autre restaurant. Videz-le d\'abord.';
      }

      context.showErrorSnack(errorMessage);
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
    showDialog<void>(
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
                  context.showSuccessSnack('Commande annulée avec succès');
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!context.mounted) return;
                  context.showErrorSnack('Erreur: ${e.toString()}');
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
                ? AppCachedImage(
                    imageUrl: itemImageUrl,
                    fit: BoxFit.cover,
                    errorWidget: _buildPlaceholderImage(context),
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
          formatPrice((item.prix * item.quantite)),
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

/// Bouton autonome gérant son propre état de chargement pendant la génération
/// et le partage du reçu PDF.
class _ReceiptButton extends ConsumerStatefulWidget {
  final String orderId;
  const _ReceiptButton({required this.orderId});

  @override
  ConsumerState<_ReceiptButton> createState() => _ReceiptButtonState();
}

class _ReceiptButtonState extends ConsumerState<_ReceiptButton> {
  bool _loading = false;

  Future<void> _download() async {
    setState(() => _loading = true);
    try {
      final bytes = await ref
          .read(orderRepositoryProvider.notifier)
          .downloadReceipt(widget.orderId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/recu-${widget.orderId}.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) {
        context.showSnack(
          e.toString().replaceFirst('Exception: ', ''),
          type: SnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _download,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Iconsax.document_download),
        label: Text(_loading ? 'Génération…' : 'Télécharger le reçu'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Invitation à noter le livreur, affichée une fois la commande livrée.
///
/// S'appuie sur `GET /deliveries/by-order/:orderId`, qui porte déjà le statut
/// de la livraison **et** la note éventuelle : pas d'appel supplémentaire pour
/// savoir si le client a déjà voté. La carte disparaît une fois la note posée
/// et laisse place au rappel de la note donnée.
class _RateDriverCard extends ConsumerWidget {
  const _RateDriverCard({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(driverLocationControllerProvider(orderId));

    return tracking.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (location) {
        // Retrait au comptoir, ou livraison sans livreur enregistré : il n'y a
        // personne à noter.
        final deliveryId = location?.deliveryId;
        if (location == null || deliveryId == null) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;
        final alreadyRated = location.myRating != null;

        if (alreadyRated) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Merci ! Vous avez noté cette livraison ${location.myRating}/5.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location.driverNom != null
                          ? 'Notez la livraison de ${location.driverNom}'
                          : 'Notez votre livraison',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final rated = await RateDriverSheet.show(
                      context,
                      deliveryId: deliveryId,
                      driverName: location.driverNom,
                    );
                    if (rated == true) {
                      // Recharge le tracking : la note revient dans le payload,
                      // la carte bascule sur le remerciement.
                      ref.invalidate(driverLocationControllerProvider(orderId));
                    }
                  },
                  icon: const Icon(Icons.star_border_rounded),
                  label: const Text('Noter le livreur'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


/// Précision textuelle sur l'avancement de la livraison.
///
/// Le stepper suit `Order.status`, qui reste `PRET` entre l'acceptation de la
/// mission et la récupération du repas — c'est voulu : la commande n'est pas
/// « en route » tant qu'elle est sur le comptoir. Mais le client gagne à savoir
/// qu'un livreur a pris la course et vient la chercher.
class _DeliveryProgressHint extends ConsumerWidget {
  const _DeliveryProgressHint({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(driverLocationControllerProvider(orderId));

    return tracking.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (location) {
        // On ne montre l'indication que pendant les étapes livreur : avant
        // l'assignation, le stepper suffit.
        if (location == null ||
            !(location.isHeadingToRestaurant || location.isOnTheWay)) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;
        final who = location.driverNom?.trim();
        final label = location.isHeadingToRestaurant && who != null
            ? '$who va récupérer votre commande'
            : location.progressLabel;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Icon(
                location.isOnTheWay
                    ? Icons.delivery_dining
                    : Icons.storefront_outlined,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


/// Traduit en action l'intention portée par la dernière notification.
///
/// L'invitation à noter est déjà traitée par `_RateDriverCard` : cette
/// bannière ne couvre que les deux cas qui appelaient une explication et
/// n'en recevaient aucune — paiement à reprendre, incident de livraison.
class _NotificationIntentBanner extends ConsumerWidget {
  const _NotificationIntentBanner({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingNotificationIntentProvider);

    // L'intention ne vaut que pour la commande qu'elle désigne.
    if (pending == null || pending.orderId != orderId) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    final (icon, color, message) = switch (pending.intent) {
      NotificationIntent.retryPayment => (
        Icons.error_outline,
        cs.error,
        'Le paiement n\'a pas abouti. Vous pouvez le relancer depuis le '
            'bouton de paiement ci-dessus.',
      ),
      NotificationIntent.deliveryIncident => (
        Icons.info_outline,
        Colors.orange,
        'Un incident est survenu pendant la livraison. Le vendeur vous '
            'recontacte pour trouver une solution.',
      ),
      // `rateDelivery` est déjà servi par _RateDriverCard ; `none` n'affiche
      // rien. On ne duplique pas l'invitation.
      _ => (null, null, null),
    };

    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color!.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
            IconButton(
              tooltip: 'Masquer',
              icon: const Icon(Icons.close, size: 18),
              // Consommer l'intention : sans ça, revenir sur la commande
              // rouvrirait la même bannière indéfiniment.
              onPressed: () => ref
                  .read(pendingNotificationIntentProvider.notifier)
                  .state = null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Relance le paiement d'une commande restée `EN_ATTENTE`.
///
/// Le même appel qu'au checkout : `POST /payments` sur la même commande. Le
/// serveur réutilise la tentative en cours s'il y en a une, ou en ouvre une
/// nouvelle si la précédente a échoué — l'application n'a rien à arbitrer.
///
/// Le montant n'est **pas** transmis : il vient de `order.total`. Afficher
/// `order.total` ici n'est qu'un rappel visuel de ce que le serveur facturera.
class _PayNowButton extends ConsumerStatefulWidget {
  const _PayNowButton({required this.order});

  final Order order;

  @override
  ConsumerState<_PayNowButton> createState() => _PayNowButtonState();
}

class _PayNowButtonState extends ConsumerState<_PayNowButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : _start,
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.wallet_check),
                  const SizedBox(width: 10),
                  Text(
                    'Payer maintenant · ${formatPrice(widget.order.total.toDouble())}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _start() async {
    // On redemande le numéro plutôt que de réutiliser celui de la commande.
    //
    // Deux raisons : le modèle client ne porte pas `contactPhone` (le numéro
    // donné au livreur n'est pas forcément celui qui paie), et une seconde
    // tentative vise souvent un autre compte — c'est précisément parce que le
    // premier n'avait pas de solde qu'on en est là.
    final choice = await _askPaymentPhone();
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final payment = await ref
          .read(paymentServiceProvider)
          .createPayment(
            orderId: widget.order.id,
            phoneNumber: choice.phone,
            method: choice.method,
          );

      if (!mounted) return;

      if (payment.isSettled) {
        ref.invalidate(userOrdersProvider);
        context.showSnack('Commande déjà réglée.');
        return;
      }

      if (payment.isInteractive) {
        context.goNamed(
          AppRoutes.paymentPending.routeName,
          pathParameters: {'paymentId': payment.paymentId},
          extra: PaymentPendingArgs(
            orderId: widget.order.id,
            amount: payment.amount > 0
                ? payment.amount
                : widget.order.total.round(),
            method: choice.method,
          ),
        );
        return;
      }

      // Mode manuel : on redonne les instructions de virement du serveur.
      await _showManualInstructions(payment);
    } catch (e) {
      if (!mounted) return;
      // Le serveur porte le motif exact (commande non payable, trop de
      // tentatives, opérateur indisponible). On l'affiche tel quel.
      context.showErrorSnack(
        e is ApiException ? e.message : 'Le paiement n\'a pas pu être relancé.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Demande le numéro et l'opérateur du paiement.
  ///
  /// Pré-rempli avec l'opérateur choisi à la commande : dans la majorité des
  /// cas, le client se contente de valider.
  Future<({String phone, String method})?> _askPaymentPhone() async {
    final controller = TextEditingController();
    var method = widget.order.paymentMethod;
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<({String phone, String method})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (innerContext, setSheetState) => Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Payer ${formatPrice(widget.order.total.toDouble())}',
                  style: Theme.of(innerContext).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'MTN_MOMO',
                      label: Text('MTN MoMo'),
                    ),
                    ButtonSegment(
                      value: 'AIRTEL_MONEY',
                      label: Text('Airtel Money'),
                    ),
                  ],
                  selected: {method},
                  onSelectionChanged: (selection) =>
                      setSheetState(() => method = selection.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Numéro Mobile Money',
                    hintText: '06 123 45 67',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final input = (value ?? '').trim();
                    if (input.isEmpty) return 'Numéro requis';
                    final ok = ref
                        .read(paymentServiceProvider)
                        .validatePhoneNumber(input);
                    return ok ? null : 'Numéro congolais invalide';
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(sheetContext).pop((
                        phone: controller.text.trim(),
                        method: method,
                      ));
                    }
                  },
                  child: const Text('Envoyer la demande de paiement'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showManualInstructions(PaymentResponse payment) async {
    final instructions = payment.instructions;
    if (instructions == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Instructions de paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(instructions.message),
            const SizedBox(height: 12),
            SelectableText(
              instructions.phone,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Référence : ${instructions.reference}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
