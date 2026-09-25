import 'package:flutter/material.dart';
import 'package:lilia_app/models/order.dart';

/// Retrait au comptoir (F3-07) : le code à montrer, puis la confirmation.
///
/// Deux preuves possibles que le client a bien récupéré sa commande — et c'est
/// l'une d'elles qui déclenche le paiement du restaurant :
///  - le restaurant saisit le **code** que le client lui montre ;
///  - le client appuie sur **« J'ai récupéré ma commande »**.
///
/// Le bouton n'apparaît que si le serveur le propose (`CONFIRM_PICKUP` dans
/// `allowedActions`) : c'est lui qui sait si la remise est déjà prouvée. La
/// carte ne déduit rien du statut.
///
/// L'appel réseau est fourni par l'écran ([onConfirm]) : la carte ne connaît
/// ni le dépôt ni les providers, ce qui la rend testable seule.
class PickupCard extends StatefulWidget {
  const PickupCard({
    super.key,
    required this.order,
    required this.onConfirm,
    required this.onConfirmed,
  });

  final Order order;

  /// `POST /orders/:id/pickup/confirm` — rend la commande à jour.
  final Future<Order> Function() onConfirm;

  /// Appelé après un succès : rafraîchir la commande, prévenir le client.
  final void Function(Order updated) onConfirmed;

  /// Rien à afficher pour cette commande ?
  static bool isRelevant(Order order) =>
      !order.isDelivery &&
      ((order.status == OrderStatus.pret && order.pickupCode != null) ||
          order.canConfirmPickup ||
          order.pickupProved);

  @override
  State<PickupCard> createState() => _PickupCardState();
}

class _PickupCardState extends State<PickupCard> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    // Double tap : un seul appel. Le serveur est idempotent de toute façon,
    // mais un second dialogue par-dessus le premier ne rassure personne.
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vous avez votre commande ?'),
        content: const Text(
          'Confirmez uniquement si vous avez bien récupéré votre commande '
          'auprès du restaurant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Pas encore'),
          ),
          FilledButton(
            key: const Key('pickup-confirm-dialog-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui, je l’ai'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.onConfirm();
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onConfirmed(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // `ApiException.toString()` est un message français prêt à afficher.
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final cs = Theme.of(context).colorScheme;

    if (order.pickupProved) {
      return _Frame(
        color: Colors.teal,
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Commande récupérée',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Votre commande a été confirmée comme retirée.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final code = order.status == OrderStatus.pret ? order.pickupCode : null;
    final vendorSaysHandedOver =
        order.deliveryProof == 'PICKUP_VENDOR_DECLARED';

    return _Frame(
      color: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (code != null) ...[
            Text(
              'Code de retrait',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Code de retrait ${code.split('').join(' ')}',
              excludeSemantics: true,
              child: Text(
                code,
                key: const Key('pickup-code'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Au comptoir, montrez ce code quand on vous remet votre '
              'commande — jamais avant.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
          if (order.canConfirmPickup) ...[
            if (code != null) const Divider(height: 28),
            if (vendorSaysHandedOver) ...[
              const Text(
                'Le restaurant indique vous avoir remis votre commande.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              code != null
                  ? 'Pas de code au comptoir ? Une fois votre commande en '
                        'main, confirmez-le ici.'
                  : 'Confirmez uniquement si vous avez bien récupéré votre '
                        'commande auprès du restaurant.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('pickup-confirm-button'),
              onPressed: _busy ? null : _confirm,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_bag_outlined),
              label: Text(
                _busy ? 'Confirmation…' : 'J’ai récupéré ma commande',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('pickup-confirm-error'),
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}
