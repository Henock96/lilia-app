import 'dart:io';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/core/support/support_contact.dart';
import 'package:lilia_app/utils/order_reference.dart';
import 'package:lilia_app/features/commandes/presentation/reorder_action.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/order_detail_cards.dart';

// `pickupStatusInfo` vit avec le reste du vocabulaire des statuts ; ré-exporté
// pour les importeurs historiques de cette page.
export 'package:lilia_app/features/commandes/presentation/status_info.dart'
    show pickupStatusInfo;
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/payments/presentation/payment_pending_args.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import '../data/order_controller.dart';
import '../data/order_repository.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';
import '../../reviews/presentation/widgets/rate_driver_sheet.dart';
import '../data/delivery_tracking_repository.dart';
import 'widgets/pickup_card.dart';
import 'widgets/report_issue_sheet.dart';
import '../../../services/analytics_service.dart';
import '../../../services/notification_router.dart';
import '../../notifications/application/notification_providers.dart';
import '../domain/order_status_view.dart';

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
                OrderHeaderCard(order: order),

                const SizedBox(height: 16),

                // Barre de progression pour les commandes en cours
                if (!_terminalStatuses.contains(order.status))
                  OrderProgressCard(order: order),

                // F3-01 : où en est le vendeur (en attente de réponse,
                // accepté, heure de fin annoncée).
                if (acceptanceLine(order) case final line?) ...[
                  const SizedBox(height: 8),
                  _AcceptanceLine(text: line),
                ],

                if (!_terminalStatuses.contains(order.status))
                  const SizedBox(height: 16),

                // P3-16 — paiement en attente : c'est la seule action qui
                // fait avancer la commande, elle passe avant le récapitulatif
                // (elle était sous les articles, la livraison et le total).
                // La bannière « paiement non abouti » la suit : son texte
                // renvoie au « bouton de paiement ci-dessus ».
                if (order.status == OrderStatus.enAttente) ...[
                  _PaymentSection(order: order),
                  const SizedBox(height: 16),
                  _NotificationIntentBanner(orderId: order.id),
                ],

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
                OrderVendorCard(order: order),

                const SizedBox(height: 16),

                // Section Articles
                OrderItemsCard(order: order),

                const SizedBox(height: 16),

                // Section Livraison
                OrderDeliveryCard(order: order),

                const SizedBox(height: 16),

                // Section Sommaire
                OrderSummaryCard(order: order),

                const SizedBox(height: 24),

                // Reçu PDF : disponible une fois la commande payée (non annulée)
                if (_receiptStatuses.contains(order.status)) ...[
                  _ReceiptButton(orderId: order.id),
                  const SizedBox(height: 16),
                ],

                // Reprise du paiement (`_PaymentSection`) — le trou que la
                // bannière `retryPayment` promettait de combler en renvoyant
                // vers « le bouton de paiement ci-dessus », qui n'existait
                // pas : montée sous l'en-tête quand la commande est
                // `EN_ATTENTE` (P3-16).

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
                // En attente de paiement, elle est déjà montée avec la
                // section de paiement.
                if (order.status != OrderStatus.enAttente)
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

                // P3.5.7 — aide joignable depuis la commande, référence
                // pré-remplie : quel que soit le statut, y compris en attente
                // de paiement, où la réclamation n'est pas ouverte.
                OrderSupportLinks(orderId: order.id),
                const SizedBox(height: 16),

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
    // `Semantics(button:)` : un `GestureDetector` nu était lu comme du texte
    // par TalkBack / VoiceOver, sans dire qu'on pouvait l'activer.
    return Semantics(
      button: true,
      label: 'Suivre le livreur en direct',
      excludeSemantics: true,
      child: GestureDetector(
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
    ),
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
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.refresh),
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

  // « Commander à nouveau » : `reorderIntoCart` (reorder_action.dart),
  // partagé avec la liste des commandes.
  void _handleReorder(BuildContext context, WidgetRef ref, String orderId) =>
      reorderIntoCart(context, ref, orderId);

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
              // `error`/`onError` : `Colors.red` + blanc = 3,68:1.
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
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
                  context.showErrorSnack(userFacingErrorMessage(e));
                }
              },
            ),
          ],
        );
      },
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
        context.showSnack(userFacingErrorMessage(e), type: SnackType.error);
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

/// « Besoin d'aide ? » : e-mail (objet = référence de la commande) ou appel.
class OrderSupportLinks extends StatelessWidget {
  const OrderSupportLinks({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ref = refCommande(orderId);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          'Besoin d\'aide ?',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        TextButton.icon(
          icon: const Icon(Icons.mail_outline, size: 18),
          label: const Text('Écrire au support'),
          onPressed: () => openSupportChannel(
            context,
            SupportContact.emailUri(orderReference: ref),
            fallbackValue: SupportContact.email,
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.call_outlined, size: 18),
          label: const Text('Appeler'),
          onPressed: () => openSupportChannel(
            context,
            SupportContact.phoneUri(),
            fallbackValue: SupportContact.phoneDisplay,
          ),
        ),
      ],
    );
  }
}

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
          context.showErrorSnack(userFacingErrorMessage(e));
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
