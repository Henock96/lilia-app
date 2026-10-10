import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/utils/snackbar.dart';

/// Geste « Annuler la commande », commun à la liste et au détail.
///
/// ## Ce qu'il corrige (audit du 09/10/2026)
///
/// - **C-06** — les deux écrans lançaient l'appel depuis le `builder` du
///   dialogue, avec **son** `context`. Le dialogue fermé avant l'`await`,
///   `context.mounted` valait `false` au retour : ni « Commande annulée », ni
///   le refus du serveur (400 quand la commande venait de passer `PAYER`).
///   Le client ne savait pas si son geste avait compté. Ici, le dialogue ne
///   fait que rendre une réponse ; l'appel et ses messages appartiennent au
///   widget qui l'a ouvert.
/// - **C-18** — aucun état « en cours » : un second tap relançait l'appel.
/// - **C-25** — l'annulation était proposée pendant qu'une demande de
///   paiement attendait sur le téléphone. Le serveur l'autorise (le client
///   peut renoncer), mais un client qui valide ensuite son code paie une
///   commande annulée, et attend un remboursement. On le lui dit avant.
///
/// La décision « annulable ou non » reste celle du serveur
/// (`canClientCancel`, verdict `allowedActions`) : ce widget n'est monté que
/// quand elle est positive.
class CancelOrderAction extends ConsumerStatefulWidget {
  const CancelOrderAction({
    super.key,
    required this.orderId,
    required this.builder,
  });

  final String orderId;

  /// Rend le bouton. [onPressed] vaut `null` pendant l'annulation.
  final Widget Function(
    BuildContext context,
    VoidCallback? onPressed,
    bool busy,
  ) builder;

  @override
  ConsumerState<CancelOrderAction> createState() => _CancelOrderActionState();
}

class _CancelOrderActionState extends ConsumerState<CancelOrderAction> {
  bool _busy = false;

  Future<void> _annuler() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final paiementEnCours = await _paiementEnCours();
      if (!mounted) return;
      final confirme = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => CancelOrderDialog(
          paymentPending: paiementEnCours,
          onAnswer: (oui) => Navigator.of(dialogContext).pop(oui),
        ),
      );
      if (confirme != true || !mounted) return;

      await ref.read(userOrdersProvider.notifier).cancelOrder(widget.orderId);
      ref.invalidate(orderPaymentProvider(widget.orderId));
      if (!mounted) return;
      context.showSuccessSnack('Commande annulée.');
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnack(userFacingErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Une demande de paiement attend-elle sur le téléphone du client ?
  ///
  /// Lecture pure (`/payments/by-order`). Illisible : on ne bloque pas
  /// l'annulation, on n'avertit simplement pas.
  Future<bool> _paiementEnCours() async {
    // Le service et non `orderPaymentProvider` : lire le `.future` d'un
    // provider auto-libéré que personne n'écoute (la liste) peut le voir
    // disparaître avant sa réponse. `getPaymentForOrder` ne lève jamais.
    final paiement = await ref
        .read(paymentServiceProvider)
        .getPaymentForOrder(widget.orderId);
    return paiement?.status == PaymentStatus.pending;
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _busy ? null : _annuler, _busy);
}

/// Confirmation d'annulation. Rend `true` (annuler) ou `false` (garder).
class CancelOrderDialog extends StatelessWidget {
  const CancelOrderDialog({
    super.key,
    required this.paymentPending,
    required this.onAnswer,
  });

  final bool paymentPending;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Annuler la commande ?')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cette action est irréversible. Êtes-vous sûr de vouloir annuler '
            'cette commande ?',
          ),
          if (paymentPending) ...[
            const SizedBox(height: 12),
            Text(
              'Un paiement est en cours de validation. Si vous avez déjà '
              'saisi votre code Mobile Money, n’annulez pas : attendez la '
              'confirmation. Sinon, ne validez pas la demande reçue sur votre '
              'téléphone après l’annulation.',
              key: const Key('cancel_payment_pending_warning'),
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => onAnswer(false),
          child: const Text('Non, garder'),
        ),
        ElevatedButton(
          // `error`/`onError` : `Colors.red` + blanc = 3,68:1.
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: () => onAnswer(true),
          child: const Text('Oui, annuler'),
        ),
      ],
    );
  }
}
