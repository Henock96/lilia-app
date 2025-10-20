import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
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

    ref.listen<String?>(latestUpdatedOrderIdProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La commande #${next.substring(0, 8)} a été mise à jour.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
        // Réinitialiser le provider pour ne pas afficher le snackbar à nouveau
        ref.read(latestUpdatedOrderIdProvider.notifier).state = null;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Commandes'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En cours'),
            Tab(text: 'Terminées'),
            Tab(text: 'Annulées'),
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
                key: const PageStorageKey('onGoingOrders'),
              ),
              _OrderListView(
                orders: completedOrders,
                key: const PageStorageKey('completedOrders'),
              ),
              _OrderListView(
                orders: cancelledOrders,
                key: const PageStorageKey('cancelledOrders'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => BuildErrorState(err),
      ),
    );
  }
}

// ... le reste du fichier (_OrderListView, _OrderCard) reste inchangé ...
class _OrderListView extends ConsumerWidget {
  final List<Order> orders;

  const _OrderListView({required this.orders, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'Aucune commande ici.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(userOrdersProvider.future),
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              context.goNamed(
                AppRoutes.orderDetail.routeName,
                pathParameters: {'orderId': orders[index].id},
              );
            },
            child: _OrderCard(order: orders[index]),
          );
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Numéro de commande : ${order.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Restaurant: ${order.restaurant.nom}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const Divider(height: 20),
            Text('Statut: ${_formatStatus(order.status)}'),
            const SizedBox(height: 8), 
            Text('Total: ${order.total.toStringAsFixed(1)} FCFA'),
            const SizedBox(height: 16),
            if (order.status == OrderStatus.enAttente)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      _showCancelConfirmationDialog(context, ref, order.id),
                  child: const Text(
                    'Annuler la commande',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
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
          title: const Text('Confirmer l\'annulation'),
          content: const Text(
            'Êtes-vous sûr de vouloir annuler cette commande ?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Non'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Oui, annuler'),
              onPressed: () async {
                Navigator.of(context).pop();
                // Vérifier à nouveau avant d'afficher le SnackBar
                if (!context.mounted) return;
                try {
                  await ref
                      .read(userOrdersProvider.notifier)
                      .cancelOrder(orderId);
                  // Vérifier à nouveau avant d'afficher le SnackBar
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Commande annulée avec succès.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Vérifier avant d'afficher l'erreur
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: Colors.red,
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

  String _formatStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.enAttente:
        return 'En attente';
      case OrderStatus.enPreparation:
        return 'En préparation';
      case OrderStatus.pret:
        return 'Prête';
      case OrderStatus.livrer:
        return 'Livrée';
      case OrderStatus.annuler:
        return 'Annulée';
      default:
        return 'Inconnu';
    }
  }
}
