import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';

import '../../../models/order_item.dart';
import '../data/order_controller.dart';

// lib/features/commandes/presentation/order_detail_page.dart
// Importez OrderItem

class OrderDetailPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(userOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Détails de la commande',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: orderAsyncValue.when(
        data: (orders) {
          final order = orders.firstWhere(
            (o) => o.id == orderId,
            orElse: () => throw Exception('Commande non trouvé !'),
          );

          final formattedDate = DateFormat(
            'dd MMM yyyy, HH:mm',
          ).format(order.createdAt);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Numéro de commande : ${order.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Commandé le: $formattedDate',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(order.status.toString()),
                      color: _getStatusColor(order.status.toString()),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getDisplayStatus(order.status.toString()),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status.toString()),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                Text(
                  'Restaurant',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: AssetImage(
                      order.restaurant.imageUrl ?? 'assets/images/logo.jpg',
                    ),
                  ),
                  title: Text(
                    order.restaurant.nom,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    order.restaurant.adresse ?? '15, Rue Banziris Poto Poto',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    // Naviguer vers la page du restaurant si vous en avez une
                  },
                ),
                const Divider(height: 30),

                Text(
                  'Article(s)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...order.items.map((item) => OrderDetailItemCard(item: item)),
                const Divider(height: 30),

                Text(
                  'Sommaire:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                _buildSummaryRow('Sous-total', order.subTotal),
                _buildSummaryRow('Prix de Livraison', order.deliveryFee),
                _buildSummaryRow('Total', order.total, isTotal: true),
                const SizedBox(height: 20),
                Text(
                  'Méthode de Paiement: ${_getDisplayStatusPaiement(order.paymentMethod)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                /*SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Action pour suivre la commande
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Suivre la commande', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Action pour l'aide
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Besoin d'aide ?", style: TextStyle(color: Colors.black, fontSize: 16)),
                  ),
                ),*/
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ),
        ),
        error: (err, stack) => BuildErrorState(err),
      ),
    );
  }

  // ... (vos méthodes _buildSummaryRow, _getDisplayStatus, _getStatusIcon, _getStatusColor) ...
  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)} FCFA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayStatus(String status) {
    switch (status) {
      case 'OrderStatus.enAttente':
        return 'En Attente';
      case 'OrderStatus.enPreparation':
        return 'En Préparation';
      case 'OrderStatus.pret':
        return 'Prête';
      case 'OrderStatus.livrer':
        return 'Livré';
      case 'OrderStatus.annuler':
        return 'Annulé';
      default:
        return 'Inconnu';
    }
  }

  String _getDisplayStatusPaiement(String status) {
    switch (status) {
      case 'CASH_ON_DELIVERY':
        return 'Payez en Cash';
      default:
        return 'MTN Mobile Money';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'OrderStatus.enAttente':
        return Icons.hourglass_empty;
      case 'OrderStatus.enPreparation':
        return Icons.cookie;
      case 'OrderStatus.pret':
        return Icons.verified_rounded;
      case 'OrderStatus.livrer':
        return Icons.check_circle;
      case 'OrderStatus.annuler':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OrderStatus.enAttente':
        return Colors.orange;
      case 'OrderStatus.enPreparation':
        return Colors.orangeAccent;
      case 'OrderStatus.pret':
        return Colors.green;
      case 'OrderStatus.livrer':
        return Colors.green;
      case 'OrderStatus.annuler':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class OrderDetailItemCard extends StatelessWidget {
  final OrderItem item;

  const OrderDetailItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // --- LOGIQUE POUR L'IMAGE DE L'ITEM ---
    final String itemImageUrl =
        item.product.imageUrl ??
        'https://via.placeholder.com/60'; // Utilise l'URL du produit ou une image par défaut
    // --- FIN LOGIQUE IMAGE DE L'ITEM ---

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(itemImageUrl), // Utilise l'URL du produit
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.nom,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${item.quantite} x ${item.variant} ',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            '${(item.prix * item.quantite).toStringAsFixed(1)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
