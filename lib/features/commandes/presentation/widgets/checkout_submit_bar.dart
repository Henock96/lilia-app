import 'package:flutter/material.dart';
import 'package:lilia_app/utils/currency.dart';

/// Barre d'action collante du checkout (P3-15).
///
/// Le bouton « Confirmez la commande » vivait en fin de défilement, sous le
/// récapitulatif : le client devait descendre tout
/// l'écran pour agir, sans voir le montant qu'il allait valider. La barre reste
/// au pied de l'écran avec le **même** total que le récapitulatif.
///
/// Elle n'arbitre rien : `onPressed` vient de la page, qui garde seule la
/// garde de double envoi et les conditions d'activation. Le montant réellement
/// dû reste celui de la commande créée par le serveur.
class CheckoutSubmitBar extends StatelessWidget {
  const CheckoutSubmitBar({
    super.key,
    required this.total,
    required this.onPressed,
    required this.isSending,
    this.disabledReason,
    this.onRetry,
  });

  /// Total du devis serveur, repris du récapitulatif — jamais recalculé ici.
  /// `null` tant que le devis n'est pas là : « calcul… » (lot 5, F-40).
  final double? total;

  /// `null` ⇒ bouton désactivé.
  final VoidCallback? onPressed;

  /// Envoi en cours : indicateur à la place du libellé.
  final bool isSending;

  /// Pourquoi le bouton est désactivé, quand ce n'est pas un envoi en cours
  /// (ex. créneau de précommande non choisi). Un bouton grisé sans
  /// explication est une impasse.
  final String? disabledReason;

  /// Relance du devis en échec, affichée sous [disabledReason]. Sans elle, un
  /// devis tombé hors ligne laissait le client sans autre issue que de
  /// quitter l'écran.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showReason =
        onPressed == null && !isSending && disabledReason != null;

    return Material(
      color: cs.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wrap et non Row : à 2× le libellé et le montant passent sur
              // deux lignes au lieu de déborder.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    total == null ? 'calcul…' : formatPrice(total!),
                    key: const Key('checkout_submit_total'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              if (showReason) ...[
                const SizedBox(height: 4),
                Text(
                  disabledReason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (onRetry != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('checkout_quote_retry'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Réessayer'),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              // Hauteur minimale et non fixe : un `SizedBox(height: 54)`
              // rognait le libellé dès que le texte est agrandi.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: ElevatedButton(
                  // Clé stable : pendant l'envoi, ce bouton n'affiche plus
                  // son libellé mais un indicateur. Un test qui le
                  // chercherait par son texte ne le retrouverait pas au
                  // second tap — et conclurait à tort que tout va bien.
                  key: const Key('checkout_submit'),
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // `onPrimary` et non blanc : en sombre l'action est un
                  // orange clair, le blanc y tombait à 2,84:1 (P3-03).
                  child: isSending
                      ? Semantics(
                          label: 'Envoi de la commande en cours',
                          child: SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: cs.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          'Confirmez la commande',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
