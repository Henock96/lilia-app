import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/models/order.dart';
import 'package:intl/intl.dart';


// La page est maintenant un ConsumerStatefulWidget pour gérer le TabController
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
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(userOrdersProvider.future),
        child: ordersAsyncValue.when(
          data: (orders) {
            // Logique de filtrage des commandes basée sur leur statut
            final onGoingOrders = orders
                .where((o) =>
                    o.status == OrderStatus.EN_ATTENTE ||
                    o.status == OrderStatus.EN_PREPARATION ||
                    o.status == OrderStatus.PRET)
                .toList();
            final completedOrders = orders
                .where((o) => o.status == OrderStatus.LIVRER)
                .toList();
            final cancelledOrders = orders
                .where((o) => o.status == OrderStatus.ANNULER)
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
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Erreur: ${err.toString()}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget pour afficher une liste de commandes
class _OrderListView extends StatelessWidget {
  final List<Order> orders;

  const _OrderListView({required this.orders, super.key});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'Aucune commande ici.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _OrderCard(order: orders[index]);
      },
    );
  }
}

// Widget pour afficher les détails d'une seule commande
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
                  'Commande #${order.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(order.createdAt),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Restaurant: ${order.restaurant.nom}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const Divider(height: 20),
            Text('Statut: ${_formatStatus(order.status)}'),
            Text('Total: ${order.total.toStringAsFixed(2)} FCFA'),
            const SizedBox(height: 16),
            // Affiche le bouton "Annuler" seulement si la commande est en attente
            if (order.status == OrderStatus.EN_ATTENTE)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showCancelConfirmationDialog(context, ref, order.id),
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

  // Affiche une boîte de dialogue de confirmation avant d'annuler
  void _showCancelConfirmationDialog(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer l\'annulation'),
          content: const Text('Êtes-vous sûr de vouloir annuler cette commande ?'),
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
                Navigator.of(context).pop(); // Ferme la dialogue
                try {
                  await ref.read(userOrdersProvider.notifier).cancelOrder(orderId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Commande annulée avec succès.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
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

  // Formate le statut pour un affichage plus convivial
  String _formatStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.EN_ATTENTE:
        return 'En attente';
      case OrderStatus.EN_PREPARATION:
        return 'En préparation';
      case OrderStatus.PRET:
        return 'Prête';
      case OrderStatus.LIVRER:
        return 'Livrée';
      case OrderStatus.ANNULER:
        return 'Annulée';
      default:
        return 'Inconnu';
    }
  }
}