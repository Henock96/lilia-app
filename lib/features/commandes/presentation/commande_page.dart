import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/models/order.dart';
import 'package:intl/intl.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

class CommandePage extends ConsumerStatefulWidget {
  const CommandePage({super.key});

  @override
  ConsumerState<CommandePage> createState() => _CommandePageState();
}

class _CommandePageState extends ConsumerState<CommandePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsyncValue = ref.watch(userOrdersProvider);
    final theme = Theme.of(context);

    ref.listen<String?>(latestUpdatedOrderIdProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 8),
                Text('Commande #${next.substring(0, 8)} mise à jour'),
              ],
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.read(latestUpdatedOrderIdProvider.notifier).state = null;
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Mes Commandes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions, size: 20),
              text: 'En cours',
            ),
            Tab(
              icon: Icon(Icons.check_circle_outline, size: 20),
              text: 'Terminées',
            ),
            Tab(
              icon: Icon(Icons.cancel_outlined, size: 20),
              text: 'Annulées',
            ),
          ],
        ),
      ),
      body: ordersAsyncValue.when(
        data: (orders) {
          final onGoingOrders = orders
              .where(
                (o) =>
                    o.status == OrderStatus.enAttente ||
                    o.status == OrderStatus.enPreparation ||
                    o.status == OrderStatus.pret,
              )
              .toList();
          final completedOrders = orders
              .where((o) => o.status == OrderStatus.livrer)
              .toList();
          final cancelledOrders = orders
              .where((o) => o.status == OrderStatus.annuler)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _OrderListView(
                orders: onGoingOrders,
                emptyMessage: 'Aucune commande en cours',
                emptyIcon: Icons.shopping_bag_outlined,
                key: const PageStorageKey('onGoingOrders'),
              ),
              _OrderListView(
                orders: completedOrders,
                emptyMessage: 'Aucune commande terminée',
                emptyIcon: Icons.check_circle_outline,
                key: const PageStorageKey('completedOrders'),
              ),
              _OrderListView(
                orders: cancelledOrders,
                emptyMessage: 'Aucune commande annulée',
                emptyIcon: Icons.cancel_outlined,
                key: const PageStorageKey('cancelledOrders'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => BuildErrorState(
          err,
          onRetry: () => ref.invalidate(userOrdersProvider),
        ),
      ),
    );
  }
}

class _OrderListView extends ConsumerWidget {
  final List<Order> orders;
  final String emptyMessage;
  final IconData emptyIcon;

  const _OrderListView({
    required this.orders,
    required this.emptyMessage,
    required this.emptyIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vos commandes apparaîtront ici',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(userOrdersProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _OrderCard(order: orders[index]);
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusInfo = _getStatusInfo(order.status);
    final firstItem = order.items.isNotEmpty ? order.items[0] : null;
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantite);

    // Image du premier produit ou du restaurant
    final imageUrl = firstItem?.product.imageUrl ?? order.restaurant.imageUrl;

    return GestureDetector(
      onTap: () {
        context.goNamed(
          AppRoutes.orderDetail.routeName,
          pathParameters: {'orderId': order.id},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // En-tête avec image et infos principales
            Row(
              children: [
                // Image du produit
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 100,
                    height: 120,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholderImage(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _buildPlaceholderImage(isLoading: true);
                            },
                          )
                        : _buildPlaceholderImage(),
                  ),
                ),

                // Informations de la commande
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Numéro de commande et date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '#${order.id.substring(0, 8).toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                            _StatusBadge(status: order.status),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Nom du restaurant
                        Text(
                          order.restaurant.nom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Produits
                        Text(
                          firstItem != null
                              ? '$itemCount article${itemCount > 1 ? 's' : ''} • ${firstItem.product.nom}${order.items.length > 1 ? ' +${order.items.length - 1}' : ''}'
                              : 'Aucun article',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // Date et total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(order.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${order.total.toStringAsFixed(0)} FCFA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Barre de progression pour les commandes en cours
            if (order.status != OrderStatus.livrer &&
                order.status != OrderStatus.annuler)
              _OrderProgressBar(status: order.status),

            // Bouton annuler pour les commandes en attente
            if (order.status == OrderStatus.enAttente)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'En attente de confirmation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showCancelConfirmationDialog(context, ref, order.id),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildPlaceholderImage({bool isLoading = false}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.fastfood, size: 40, color: Colors.grey[400]),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Aujourd'hui ${DateFormat('HH:mm').format(date)}";
    } else if (difference.inDays == 1) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  _StatusInfo _getStatusInfo(OrderStatus status) {
    switch (status) {
      case OrderStatus.enAttente:
        return _StatusInfo(
          label: 'En attente',
          color: Colors.orange,
          icon: Icons.hourglass_empty,
        );
      case OrderStatus.enPreparation:
        return _StatusInfo(
          label: 'En préparation',
          color: Colors.blue,
          icon: Icons.restaurant,
        );
      case OrderStatus.pret:
        return _StatusInfo(
          label: 'Prête',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case OrderStatus.livrer:
        return _StatusInfo(
          label: 'Livrée',
          color: Colors.teal,
          icon: Icons.local_shipping,
        );
      case OrderStatus.annuler:
        return _StatusInfo(
          label: 'Annulée',
          color: Colors.red,
          icon: Icons.cancel,
        );
      default:
        return _StatusInfo(
          label: 'Inconnu',
          color: Colors.grey,
          icon: Icons.help_outline,
        );
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  await ref.read(userOrdersProvider.notifier).cancelOrder(orderId);
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
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final info = _getStatusInfo(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 12, color: info.color),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(OrderStatus status) {
    switch (status) {
      case OrderStatus.enAttente:
        return _StatusInfo(
          label: 'En attente',
          color: Colors.orange,
          icon: Icons.hourglass_empty,
        );
      case OrderStatus.enPreparation:
        return _StatusInfo(
          label: 'En préparation',
          color: Colors.blue,
          icon: Icons.restaurant,
        );
      case OrderStatus.pret:
        return _StatusInfo(
          label: 'Prête',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case OrderStatus.livrer:
        return _StatusInfo(
          label: 'Livrée',
          color: Colors.teal,
          icon: Icons.local_shipping,
        );
      case OrderStatus.annuler:
        return _StatusInfo(
          label: 'Annulée',
          color: Colors.red,
          icon: Icons.cancel,
        );
      default:
        return _StatusInfo(
          label: 'Inconnu',
          color: Colors.grey,
          icon: Icons.help_outline,
        );
    }
  }
}

class _OrderProgressBar extends StatelessWidget {
  final OrderStatus status;

  const _OrderProgressBar({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = ['Confirmée', 'En préparation', 'Prête', 'En route'];
    int currentStep = 0;

    switch (status) {
      case OrderStatus.enAttente:
        currentStep = 0;
        break;
      case OrderStatus.enPreparation:
        currentStep = 1;
        break;
      case OrderStatus.pret:
        currentStep = 2;
        break;
      default:
        currentStep = 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Ligne entre les étapes
            final stepIndex = index ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepIndex < currentStep
                    ? Colors.green
                    : Colors.grey[300],
              ),
            );
          } else {
            // Point d'étape
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex <= currentStep;
            final isCurrent = stepIndex == currentStep;

            return Column(
              children: [
                Container(
                  width: isCurrent ? 16 : 12,
                  height: isCurrent ? 16 : 12,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.grey[300],
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: isCompleted && !isCurrent
                      ? const Icon(Icons.check, size: 8, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? Colors.green : Colors.grey[500],
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  _StatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}
