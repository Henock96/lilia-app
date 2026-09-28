import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/features/cart/presentation/line_options_text.dart';
import 'package:lilia_app/features/commandes/data/delivery_tracking_repository.dart';
import 'package:lilia_app/features/commandes/presentation/progress_step.dart';
import 'package:lilia_app/features/commandes/presentation/status_info.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/handover_code_card.dart';
import 'package:lilia_app/models/location_precision.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/models/order_item.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/map_launcher.dart';
import 'package:lilia_app/utils/order_reference.dart';

// Cartes **d'affichage** du détail de commande, extraites de
// `commande_detail_page.dart` (2 414 lignes). Elles lisent une `Order` et
// n'agissent sur rien : paiement, annulation, réclamation, recommande et
// notation restent dans la page, avec leurs providers.

class OrderHeaderCard extends StatelessWidget {
  const OrderHeaderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final formattedDate = DateFormat(
      'dd MMM yyyy',
      'fr_FR',
    ).format(order.createdAt);
    final formattedTime = DateFormat('HH:mm').format(order.createdAt);
    final statusInfo = pickupStatusInfo(order) ?? orderStatusInfo(order.status);
    final (statusBg, statusFg) = statusInfo.colors(context);

    return _OrderCard(
      padding: 20,
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
              OrderStatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(statusInfo.icon, color: statusFg, size: 24),
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
                          color: statusFg,
                        ),
                      ),
                      Text(
                        statusInfo.description,
                        style: TextStyle(fontSize: 12, color: statusFg),
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
}

class OrderProgressCard extends StatelessWidget {
  const OrderProgressCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _OrderCard(
      padding: 20,
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
}

class OrderVendorCard extends StatelessWidget {
  const OrderVendorCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _OrderCard(
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
}

class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantite,
    );

    return _OrderCard(
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
}

class OrderDeliveryCard extends StatelessWidget {
  const OrderDeliveryCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDelivery = order.isDelivery;

    return _OrderCard(
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
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDelivery ? Iconsax.location : Iconsax.shop,
                  color: cs.onPrimaryContainer,
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
                          color: cs.successText,
                          text: 'Position exacte enregistrée',
                        ),
                        LocationPrecision.approximate => _PrecisionLine(
                          icon: Icons.gps_not_fixed,
                          color: cs.warningText,
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
}

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _OrderCard(
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
      ? cs.successText
      : cs.onSurface;
  final formatted = formatPrice(value);
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          if (isDiscount) ...[
            Icon(Icons.local_offer, size: 14, color: cs.successText),
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
                  ? cs.successText
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

Widget _buildPlaceholderImage(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    color: cs.surfaceContainerHighest,
    child: Center(child: Icon(Iconsax.shop, size: 30, color: cs.outline)),
  );
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
                    ? cs.successText
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
    final atteinte = step.isCompleted || step.isCurrent;
    // Texte : `successText` / `onSurfaceVariant`. L'étape à venir était
    // écrite en `outline` (≈ 1.2:1 en clair) et l'étape faite en
    // `Colors.green` (≈ 2.5:1), en 11 px.
    final textColor = atteinte ? cs.successText : cs.onSurfaceVariant;
    final etat = step.isCurrent
        ? 'en cours'
        : step.isCompleted
        ? 'terminée'
        : 'à venir';

    return Semantics(
      label: '${step.label}, $etat',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: step.isCurrent ? 44 : 36,
            height: step.isCurrent ? 44 : 36,
            decoration: BoxDecoration(
              color: atteinte
                  ? cs.successText.withValues(alpha: 0.1)
                  : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: step.isCurrent
                  ? Border.all(color: cs.successText, width: 2)
                  : null,
            ),
            child: Icon(
              step.icon,
              size: step.isCurrent ? 22 : 18,
              color: atteinte ? cs.successText : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: step.isCurrent ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

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
        return Column(
          children: [
            hint,
            HandoverCodeCard(code: code),
          ],
        );
      },
    );
  }
}

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

/// Conteneur commun des cartes du détail — une seule définition au lieu de
/// six copies de la même décoration.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.child, this.padding = LiliaSpacing.md});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: LiliaRadius.lgAll,
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }
}
