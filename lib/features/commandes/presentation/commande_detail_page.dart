import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lilia_app/utils/order_reference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/features/commandes/presentation/progress_step.dart';
import 'package:lilia_app/features/commandes/presentation/status_info.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/payments/presentation/payment_pending_args.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import '../../../models/location_precision.dart';
import '../../../models/order_item.dart';
import '../../../utils/map_launcher.dart';
import '../../cart/application/cart_controller.dart';
import '../data/order_controller.dart';
import '../data/order_repository.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';
import '../../reviews/presentation/widgets/rate_driver_sheet.dart';
import '../data/delivery_tracking_repository.dart';
import 'widgets/handover_code_card.dart';
import 'widgets/pickup_card.dart';
import 'widgets/report_issue_sheet.dart';
import '../../../services/analytics_service.dart';
import '../../../services/notification_router.dart';
import '../../notifications/application/notification_providers.dart';
import '../domain/order_status_view.dart';
import 'package:lilia_app/features/cart/presentation/line_options_text.dart';

/// Statuts pour lesquels le reçu PDF est téléchargeable (payée, non annulée).
const _receiptStatuses = <OrderStatus>{
  OrderStatus.payer,
  OrderStatus.acceptee,
  OrderStatus.enPreparation,
  OrderStatus.pret,
  OrderStatus.enRoute,
  OrderStatus.livrer,
  OrderStatus.echecLivraison,
};

class OrderDetailPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ La source de vérité est `GET /orders/:id`, **pas** la liste.
    //
    // Cet écran filtrait `userOrdersProvider` — la première page de
    // l'historique, vingt commandes. Toute commande plus ancienne affichait
    // « Cette commande n'est plus disponible », ce qui est faux : elle
    // existe, et le serveur sait la rendre. C'est le cas d'une notification
    // tardive, d'un ancien reçu, ou simplement d'un client fidèle.
    final detailAsync = ref.watch(orderDetailProvider(orderId));
    // La liste sert de **premier rendu** quand on arrive depuis elle : la
    // commande est déjà en mémoire, l'afficher évite un écran de chargement
    // pour une donnée qu'on a sous la main. Elle ne sert jamais à conclure
    // qu'une commande n'existe pas.
    final depuisListe = ref
        .watch(userOrdersProvider)
        .value
        ?.where((o) => o.id == orderId)
        .firstOrNull;
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

        // Le bouton « Partager » a été RETIRÉ : son `onPressed` était `() {}`.
        // Un bouton visible qui ne fait rien coûte plus qu'un bouton absent —
        // le client croit à une panne, et le support cherche une cause qui
        // n'existe pas. À réintroduire le jour où il y a quelque chose à
        // partager (le suivi ? le reçu ?), avec une décision sur quoi.
      ),
      body: Builder(
        builder: (context) {
          final order = detailAsync.value ?? depuisListe;

          // ⚠️ `isLoading && !hasError` : Riverpod 3 relance automatiquement un
          // provider en échec. Entre deux tentatives il repasse en chargement
          // tout en portant son erreur — un écran qui ne regarde que
          // `isLoading` tourne alors indéfiniment au lieu de dire ce qui ne va
          // pas, et n'offre jamais son bouton « Réessayer ».
          if (order == null && detailAsync.isLoading && !detailAsync.hasError) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          if (order == null) {
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
                    // Le message n'affirme plus que la commande a disparu :
                    // le plus souvent, c'est la lecture qui a échoué.
                    Text(
                      detailAsync.hasError
                          ? 'Nous n’avons pas pu charger cette commande. '
                                'Vérifiez votre connexion et réessayez.'
                          : 'Cette commande n’est plus disponible ou a été '
                                'retirée de votre liste.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Retour'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.invalidate(orderDetailProvider(orderId)),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header avec statut
                _buildHeaderCard(context, order),

                const SizedBox(height: 16),

                // Barre de progression pour les commandes en cours
                if (!_terminalStatuses.contains(order.status))
                  _buildProgressCard(context, order),

                // F3-01 : où en est le vendeur (en attente de réponse,
                // accepté, heure de fin annoncée).
                if (acceptanceLine(order) case final line?) ...[
                  const SizedBox(height: 8),
                  _AcceptanceLine(text: line),
                ],

                if (!_terminalStatuses.contains(order.status))
                  const SizedBox(height: 16),

                // Commande annulée : payée ⇒ le remboursement est automatique,
                // il faut le dire (et le motif du vendeur s'il y en a un).
                if (order.status == OrderStatus.annuler) ...[
                  _CancellationCard(notice: cancellationNotice(order)),
                  const SizedBox(height: 16),
                ],

                // F3-07 — retrait au comptoir : code à montrer, puis
                // « J'ai récupéré ma commande ».
                if (PickupCard.isRelevant(order)) ...[
                  PickupCard(
                    order: order,
                    onConfirm: () => ref
                        .read(orderRepositoryProvider.notifier)
                        .confirmPickup(order.id),
                    onConfirmed: (_) {
                      ref.invalidate(orderDetailProvider(orderId));
                      ref.invalidate(userOrdersProvider);
                      if (!context.mounted) return;
                      context.showSuccessSnack(
                        'Commande récupérée. Bon appétit !',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

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
                  _PaymentSection(order: order),
                  const SizedBox(height: 12),
                ],

                // Bouton Annuler : le serveur publie les gestes permis
                // (F3-01, règle R1) ; avant paiement face à un serveur antérieur.
                if (canClientCancel(order))
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

                // F-06 : le recours qui manquait — une commande déclarée
                // livrée sans l'être n'avait aucune porte de sortie.
                // F3-06 — livrée : réclamation détaillée (articles, photo,
                // fil avec le service client), 24 h. Avant : signalement F-06.
                if (order.status == OrderStatus.livrer) ...[
                  _ClaimButton(orderId: order.id),
                  const SizedBox(height: 16),
                ] else if (_reportableStatuses.contains(order.status)) ...[
                  _ReportIssueButton(orderId: order.id),
                  const SizedBox(height: 16),
                ],

                // Bouton Commander à nouveau pour les commandes livrées ou annulées
                if (order.status == OrderStatus.livrer ||
                    order.status == OrderStatus.annuler)
                  _buildReorderButton(context, ref, order.id),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackingButton(BuildContext context, String orderId) {
    //final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.pushNamed(
        AppRoutes.orderTracking.routeName,
        pathParameters: {'orderId': orderId},
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
    final statusInfo = pickupStatusInfo(order) ?? _getStatusInfo(order.status);

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
                    refCommande(order.id),
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
    final isDelivery = order.isDelivery;

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
                  Icon(
                    isDelivery ? Iconsax.truck_fast : Iconsax.shop,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDelivery ? 'Livraison' : 'Retrait en magasin',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // `hasDeliveryCoordinates` et non un simple test de nullité :
              // il exige aussi que le serveur ait qualifié la position. Des
              // coordonnées résiduelles sur une destination `UNKNOWN`
              // ouvriraient un itinéraire vers un point que personne n'a posé
              // — et on s'y rendrait.
              if (isDelivery && order.hasDeliveryCoordinates)
                TextButton.icon(
                  onPressed: () => MapLauncher.openNavigation(
                    latitude: order.deliveryLatitude!,
                    longitude: order.deliveryLongitude!,
                    label: 'Livraison - Commande ${refCommande(order.id)}',
                    address: order.deliveryAddress,
                  ),
                  icon: const Icon(Icons.navigation_outlined, size: 16),
                  label: const Text(
                    'Itinéraire',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDelivery ? Colors.blue[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDelivery ? Iconsax.location : Iconsax.shop,
                  color: isDelivery ? Colors.blue[400] : Colors.orange[400],
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDelivery
                          ? 'Adresse de destination'
                          : 'Adresse du restaurant',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDelivery
                          ? (order.deliveryAddress ?? 'Adresse non spécifiée')
                          : (order.restaurant.adresse ??
                                'Adresse non disponible'),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    if (isDelivery &&
                        order.deliveryLandmark != null &&
                        order.deliveryLandmark!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Repère : ${order.deliveryLandmark}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Note : "${order.notes}"',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (order.contactPhone != null &&
                        order.contactPhone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Contact : ${order.contactPhone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    // Fiabilité de la destination, dans les trois cas.
                    //
                    // Seul `exact` était affiché : l'interface rassurait quand
                    // tout allait bien et se taisait quand il y avait un
                    // problème. Or c'est l'inverse qui est utile — un client
                    // qui sait que le livreur va devoir l'appeler garde son
                    // téléphone à portée, et peut encore situer son adresse.
                    if (isDelivery) ...[
                      const SizedBox(height: 6),
                      switch (order.deliveryPrecision) {
                        LocationPrecision.exact => _PrecisionLine(
                          icon: Icons.gps_fixed,
                          color: Colors.green.shade700,
                          text: 'Position exacte enregistrée',
                        ),
                        LocationPrecision.approximate => _PrecisionLine(
                          icon: Icons.gps_not_fixed,
                          color: Colors.orange.shade800,
                          text:
                              'Position au quartier — le livreur vous '
                              'appellera en arrivant',
                        ),
                        LocationPrecision.unknown => _PrecisionLine(
                          icon: Icons.gps_off,
                          color: cs.error,
                          text:
                              'Aucune position enregistrée — le livreur vous '
                              'appellera',
                        ),
                      },
                    ],
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

  /// Raisons des lignes non rachetées (au plus trois), telles que le serveur
  /// les formule.
  List<String> _reorderReasons(Map<String, dynamic> result) {
    final details = result['details'];
    final unavailable = details is Map<String, dynamic>
        ? details['unavailable']
        : null;
    if (unavailable is! List) return const [];
    return unavailable
        .whereType<Map<String, dynamic>>()
        .map((u) => u['reason'])
        .whereType<String>()
        .take(3)
        .map((r) => '• $r')
        .toList();
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
          // F3-10 — dire pourquoi (format retiré, stock insuffisant…) : le
          // serveur n'ajoute plus jamais un autre format à la place.
          final reasons = _reorderReasons(result);
          if (reasons.isNotEmpty) message += ' :\n${reasons.join('\n')}';
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
      case OrderStatus.acceptee:
        return StatusInfo(
          label: 'Acceptée',
          description: 'Le vendeur a accepté votre commande',
          color: Colors.lightGreen,
          icon: Iconsax.like_1,
        );
      case OrderStatus.echecLivraison:
        return StatusInfo(
          label: 'Livraison non aboutie',
          description: 'Votre commande n’a pas pu être livrée — le support revient vers vous',
          color: Colors.deepOrange,
          icon: Iconsax.warning_2,
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
              // F3-09 — options figées de la commande.
              LineOptionsText(item.options),
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

        final hint = Padding(
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

        // F-06 : pendant que le repas roule, le client a son code de remise
        // sous les yeux — c'est lui qui le donnera au livreur à la porte.
        final code = location.handoverCode;
        if (!location.isOnTheWay || code == null) return hint;
        return Column(children: [hint, HandoverCodeCard(code: code)]);
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
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
            IconButton(
              tooltip: 'Masquer',
              icon: const Icon(Icons.close, size: 18),
              // Consommer l'intention : sans ça, revenir sur la commande
              // rouvrirait la même bannière indéfiniment.
              onPressed: () =>
                  ref.read(pendingNotificationIntentProvider.notifier).state =
                      null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Arbitre entre « un paiement est en cours » et « vous pouvez payer ».
///
/// **Pourquoi ce widget existe.** Le bouton de reprise s'affichait dès que la
/// commande était `EN_ATTENTE`, sans regarder s'il y avait déjà une tentative en
/// cours. Le client voyait donc « Payer maintenant » pendant qu'une demande
/// attendait sur son téléphone — l'invitation la plus directe au double
/// paiement.
///
/// Le serveur protège l'argent de toute façon : il réutilise la tentative
/// `PENDING` au lieu d'en ouvrir une seconde, et ne resollicite pas l'opérateur
/// si la demande lui a déjà été soumise. Ce widget ne remplace pas cette
/// garantie — il évite de proposer un geste que le serveur refusera.
///
/// En cas d'échec de la lecture, on retombe volontairement sur le bouton :
/// mieux vaut un client qui peut payer (le serveur arbitrera) qu'un client
/// bloqué par une requête de confort qui n'a pas abouti.
class _PaymentSection extends ConsumerWidget {
  const _PaymentSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderPaymentProvider(order.id));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => _PayNowButton(order: order),
      data: (payment) {
        if (payment?.status == PaymentStatus.pending) {
          return _PaymentInProgressCard(orderId: order.id);
        }
        return _PayNowButton(order: order);
      },
    );
  }
}

/// Un paiement est en cours : on informe, on ne propose pas de recommencer.
class _PaymentInProgressCard extends ConsumerWidget {
  const _PaymentInProgressCard({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Paiement en cours',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Nous vérifions votre paiement. Cela peut prendre quelques '
            'instants. Ne relancez pas le paiement : votre commande sera '
            'confirmée dès que l’opérateur aura répondu.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => ref.invalidate(orderPaymentProvider(orderId)),
              child: const Text('Vérifier maintenant'),
            ),
          ),
        ],
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

      // `payment_started` — une nouvelle tentative d'encaissement existe.
      // Unique par `paymentId` : si le serveur a réutilisé une tentative
      // PENDING existante, c'est le même identifiant et l'événement ne repart
      // pas ; une vraie seconde tentative, elle, compte — c'est l'écart avec
      // `payment_success` qui mesure les échecs d'opérateur.
      AnalyticsService.trackPaymentStarted(
        paymentId: payment.paymentId,
        orderId: widget.order.id,
        paymentMethod: choice.method,
        amount: payment.amount > 0
            ? payment.amount
            : widget.order.total.round(),
      );

      if (payment.isSettled) {
        // Le serveur annonce l'encaissement déjà réglé — c'est sa vérité, pas
        // une supposition d'écran.
        AnalyticsService.trackPaymentSuccess(
          paymentId: payment.paymentId,
          orderId: widget.order.id,
          paymentMethod: choice.method,
          amount: payment.amount > 0
              ? payment.amount
              : widget.order.total.round(),
        );
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

    // ⚠️ Le contrôleur est créé ici, donc il doit être libéré ici.
    //
    // Il ne l'était pas : la feuille pouvait être ouverte, fermée, rouverte à
    // chaque tentative de paiement, et chaque passage laissait un
    // `TextEditingController` vivant. Un `ChangeNotifier` non libéré retient
    // ses auditeurs et son propre état ; la fuite est minuscule, mais elle est
    // exactement du genre qui se recopie au prochain `showModalBottomSheet`.
    //
    // `whenComplete` et non un `dispose()` après l'`await` : la feuille peut
    // être rejetée par un geste, la `Future` se résout alors par `null` sans
    // repasser par le chemin nominal.
    try {
      return await showModalBottomSheet<({String phone, String method})>(
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
                      ButtonSegment(value: 'MTN_MOMO', label: Text('MTN MoMo')),
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
                        Navigator.of(
                          sheetContext,
                        ).pop((phone: controller.text.trim(), method: method));
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
    } finally {
      controller.dispose();
    }
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

/// Ligne « fiabilité de la destination », sous l'adresse de livraison.
///
/// Trois états, trois conduites différentes pour le client : ne rien faire,
/// garder son téléphone à portée, ou compléter son adresse. Les confondre en
/// un seul message — ou n'en afficher qu'un — revenait à ne rien dire.
class _PrecisionLine extends StatelessWidget {
  const _PrecisionLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

/// Statuts sur lesquels un signalement a un sens — le serveur applique la
/// même liste (et une fenêtre de 72 h après livraison).
const _reportableStatuses = {
  OrderStatus.payer,
  OrderStatus.acceptee,
  OrderStatus.enPreparation,
  OrderStatus.pret,
  OrderStatus.enRoute,
  OrderStatus.livrer,
  // F3-05 : un client doit pouvoir contester l'issue d'un échec (miroir serveur).
  OrderStatus.echecLivraison,
};

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('open-claim'),
    icon: const Icon(Icons.support_agent_outlined),
    label: const Text('Un problème avec ma commande ?'),
    onPressed: () => context.pushNamed(
      AppRoutes.claimForm.routeName,
      pathParameters: {'orderId': orderId},
    ),
  );
}

class _ReportIssueButton extends ConsumerWidget {
  const _ReportIssueButton({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: const Key('report-issue'),
      icon: const Icon(Icons.flag_outlined),
      label: const Text('Signaler un problème'),
      onPressed: () async {
        final report = await showReportIssueSheet(context);
        if (report == null || !context.mounted) return;
        try {
          await ref
              .read(orderRepositoryProvider.notifier)
              .reportIssue(orderId, report.kind.wire, message: report.message);
          if (!context.mounted) return;
          context.showSuccessSnack(
            'Signalement transmis. Notre équipe vous recontacte rapidement.',
          );
        } catch (e) {
          if (!context.mounted) return;
          context.showErrorSnack('$e');
        }
      },
    );
  }
}

/// Statuts sans suite : pas de progression à afficher.
const _terminalStatuses = {
  OrderStatus.livrer,
  OrderStatus.annuler,
  OrderStatus.echecLivraison,
};

/// Ligne d'état de l'acceptation vendeur (F3-01).
class _AcceptanceLine extends StatelessWidget {
  const _AcceptanceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Iconsax.clock, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

/// Annulation expliquée : remboursement en cours si la commande était payée.
class _CancellationCard extends StatelessWidget {
  const _CancellationCard({required this.notice});

  final ({String title, String detail}) notice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.close_circle, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(notice.detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête d'un retrait au comptoir (F3-07) : « prête pour la livraison » et
/// « livrée » n'ont pas de sens pour une commande qu'on vient chercher.
/// `null` : le libellé général convient.
StatusInfo? pickupStatusInfo(Order order) {
  if (order.isDelivery) return null;
  switch (order.status) {
    case OrderStatus.pret:
      return StatusInfo(
        label: 'Prête',
        description: 'Votre commande vous attend au restaurant',
        color: Colors.green,
        icon: Iconsax.shop,
      );
    case OrderStatus.livrer:
      return order.deliveryProof == 'PICKUP_VENDOR_DECLARED'
          ? StatusInfo(
              label: 'Remise',
              description: 'Le restaurant indique vous avoir remis la commande',
              color: Colors.teal,
              icon: Iconsax.shop,
            )
          : StatusInfo(
              label: 'Récupérée',
              description: 'Vous avez récupéré votre commande',
              color: Colors.teal,
              icon: Iconsax.verify,
            );
    default:
      return null;
  }
}
