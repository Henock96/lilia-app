import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/payments/domain/payment_failure.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/utils/currency.dart';

/// Écran d'attente pendant qu'un paiement Mobile Money se joue.
///
/// Il remplace la modale d'instructions du mode manuel : avec un prestataire,
/// le client n'a plus de virement à composer — il reçoit une demande sur son
/// téléphone et saisit son code.
///
/// **Jamais un simple indicateur de chargement.** L'écran affiche le montant,
/// l'opérateur et le temps écoulé, parce qu'un client qui ne sait pas ce qu'on
/// attend de lui raccroche. Le rappel USSD (`*105#` / `*555#`) est un secours
/// quand la demande automatique n'arrive pas — ce qui se produit sur les réseaux
/// congolais.
class PaymentPendingPage extends ConsumerStatefulWidget {
  const PaymentPendingPage({
    super.key,
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.method,
  });

  final String paymentId;
  final String orderId;
  final int amount;

  /// `MTN_MOMO` ou `AIRTEL_MONEY`.
  final String method;

  @override
  ConsumerState<PaymentPendingPage> createState() => _PaymentPendingPageState();
}

class _PaymentPendingPageState extends ConsumerState<PaymentPendingPage> {
  bool _navigated = false;

  bool get _isMtn => widget.method == 'MTN_MOMO';
  String get _methodLabel => _isMtn ? 'MTN Mobile Money' : 'Airtel Money';
  String get _ussd => _isMtn ? '*105#' : '*555#';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentStatusControllerProvider(widget.paymentId));

    // Un push FCM concernant CETTE commande déclenche une vérification
    // immédiate — sans faire du payload de notification une source financière.
    ref.listen<String?>(latestUpdatedOrderIdProvider, (_, next) {
      if (next == widget.orderId) {
        ref
            .read(paymentStatusControllerProvider(widget.paymentId).notifier)
            .onPushReceived();
      }
    });

    ref.listen<PaymentWaitState>(
        paymentStatusControllerProvider(widget.paymentId), (_, next) {
      if (next.phase == PaymentWaitPhase.succeeded) _onSucceeded();
      if (next.phase == PaymentWaitPhase.failed) {
        _onFailed(next.outcome, next.failureCode);
      }
    });

    return PopScope(
      // Le retour arrière est neutralisé : quitter par accident laisserait le
      // client sans savoir où en est son paiement. La sortie explicite est le
      // bouton « J'ai un problème ».
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                _buildAnimation(context, state),
                const SizedBox(height: 32),
                Text(
                  state.phase == PaymentWaitPhase.undetermined
                      ? 'Paiement toujours en cours'
                      : 'Validez le paiement',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.phase == PaymentWaitPhase.undetermined
                      ? 'Nous n’avons pas encore reçu la confirmation de l’opérateur. '
                          'Si vous avez validé, votre commande sera confirmée d’ici quelques minutes.'
                      : 'Une demande de paiement a été envoyée sur votre téléphone. '
                          'Saisissez votre code secret $_methodLabel pour confirmer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                _buildAmountCard(context),
                const SizedBox(height: 20),
                if (state.phase != PaymentWaitPhase.undetermined)
                  _buildUssdHint(context, state),
                const Spacer(),
                _buildActions(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation(BuildContext context, PaymentWaitState state) {
    final cs = Theme.of(context).colorScheme;
    final undetermined = state.phase == PaymentWaitPhase.undetermined;

    return Center(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!undetermined)
              const SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            Icon(
              undetermined ? Icons.schedule : Icons.phone_android,
              size: 40,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Montant à payer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            // Le montant vient du serveur (`order.total`), pas d'un recalcul.
            formatPrice(widget.amount.toDouble()),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(_methodLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildUssdHint(BuildContext context, PaymentWaitState state) {
    final cs = Theme.of(context).colorScheme;
    final seconds = state.elapsed.inSeconds;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
                '${(seconds % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [],
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          // Le rappel n'apparaît qu'après 20 s : l'afficher tout de suite
          // suggérerait que la demande automatique ne marche pas.
          if (seconds >= 20) ...[
            const SizedBox(height: 10),
            Text(
              'Vous n’avez rien reçu ? Composez $_ussd sur votre téléphone '
              'et validez le paiement en attente.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, PaymentWaitState state) {
    if (state.phase == PaymentWaitPhase.undetermined) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => ref
                .read(
                  paymentStatusControllerProvider(widget.paymentId).notifier,
                )
                .refreshNow(),
            child: const Text('Vérifier maintenant'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _goToOrders,
            child: const Text('Voir mes commandes'),
          ),
        ],
      );
    }

    return TextButton(
      onPressed: () => _showHelpSheet(context),
      child: const Text('J’ai un problème'),
    );
  }

  Future<void> _showHelpSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paiement en attente',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Votre commande est enregistrée. Si vous quittez cet écran, elle '
              'reste payable depuis « Mes commandes ». Ne payez pas deux fois : '
              'nous confirmons automatiquement dès réception.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _goToOrders();
              },
              child: const Text('Voir mes commandes'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Continuer d’attendre'),
            ),
          ],
        ),
      ),
    );
  }

  void _onSucceeded() {
    if (_navigated || !mounted) return;
    _navigated = true;

    // ── `payment_success` ────────────────────────────────────────────────────
    //
    // **Le seul émetteur de l'application.** Il ne part pas parce que cet écran
    // s'affiche, ni parce que le client a saisi son code : il part parce que
    // `PaymentStatusController` a lu `SUCCESS` sur `GET /payments/:id/status`,
    // c'est-à-dire parce que le prestataire l'a confirmé au serveur — par le
    // webhook, l'interrogation ou le cron de réconciliation.
    //
    // C'est la même autorité que celle qui fait passer la commande en `PAYER`.
    // Un push FCM ne suffit pas et n'est d'ailleurs pas utilisé comme tel : il
    // ne fait que déclencher une vérification immédiate.
    //
    // Unique par `paymentId` : le détail de la commande observe le même
    // paiement, et le client peut revenir sur cet écran.
    AnalyticsService.trackPaymentSuccess(
      paymentId: widget.paymentId,
      orderId: widget.orderId,
      paymentMethod: widget.method,
      amount: widget.amount,
    );

    // Le panier n'est vidé qu'ICI, sur une confirmation serveur. Le vider au
    // départ du paiement effaçait la sélection d'un client dont le paiement
    // pouvait échouer.
    ref.read(cartControllerProvider.notifier).clearCart();
    ref.invalidate(userOrdersProvider);
    context.goNamed(AppRoutes.orderSuccess.routeName);
  }

  /// Issue non aboutie — échec, annulation ou expiration.
  ///
  /// Le texte vient **toujours** de `mapPaymentFailure`, jamais du serveur : le
  /// `failureMessage` qu'il renvoie est celui de l'opérateur, dans sa langue et
  /// son style. C'est lui qui affichait « "Airtel_CG" did not specify a reason
  /// for this faliure » au client.
  Future<void> _onFailed(PaymentOutcome? outcome, String? failureCode) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // Échec confirmé par le serveur. Seule la **catégorie** part : le
    // `failureMessage` du prestataire est un texte libre, dans sa langue, qu'on
    // ne montre déjà pas au client.
    AnalyticsService.trackPaymentFailed(
      orderId: widget.orderId,
      paymentMethod: widget.method,
      failureKind: outcome?.name ?? 'unknown',
    );

    final message = mapPaymentFailure(
      // L'écran ne distingue pas `failed` de `cancelled` au niveau du statut :
      // c'est le code qui porte la nuance, et le mapper qui la rend.
      status: outcome == PaymentOutcome.cancelled
          ? PaymentStatus.cancelled
          : PaymentStatus.failed,
      failureCode: failureCode,
    );

    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(message.title),
        content: Text(
          '${message.body}\n\n'
          'Votre commande est conservée : vous pouvez réessayer maintenant ou '
          'plus tard depuis « Mes commandes ».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Plus tard'),
          ),
          if (message.canRetry)
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Réessayer'),
            ),
        ],
      ),
    );

    if (!mounted) return;

    // Dans les deux cas on va aux commandes : le bouton « Payer maintenant » y
    // relance le paiement. Un second écran de saisie ici dupliquerait ce flux.
    ref.invalidate(userOrdersProvider);
    if (retry == true) {
      context.goNamed(
        AppRoutes.orderDetail.routeName,
        pathParameters: {'orderId': widget.orderId},
      );
    } else {
      _goToOrders();
    }
  }

  void _goToOrders() {
    if (!mounted) return;
    ref.invalidate(userOrdersProvider);
    context.goNamed(AppRoutes.commandes.routeName);
  }
}
