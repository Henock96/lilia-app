import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';

/// Instructions de virement mobile money, après création de la commande et du
/// paiement.
///
/// **Affichage seul.** Numéro, montant et référence arrivent résolus par
/// `CheckoutPage` depuis la réponse serveur (`payment.instructions`) : le
/// montant est celui de la commande créée, jamais un recalcul client. Les deux
/// gestes (« Plus tard », « J'ai payé ») restent à la page, qui vide le panier
/// et navigue.
class PaymentInstructionsDialog extends StatelessWidget {
  const PaymentInstructionsDialog({
    super.key,
    required this.isMtn,
    required this.methodLabel,
    required this.paymentPhoneNumber,
    required this.amountDue,
    required this.reference,
    required this.onLater,
    required this.onPaid,
  });

  final bool isMtn;
  final String methodLabel;
  final String paymentPhoneNumber;
  final double amountDue;
  final String reference;
  final VoidCallback onLater;
  final VoidCallback onPaid;

  static const _etapesMtn = [
    'Composez *105#',
    'Choisissez « Envoi d\'argent »',
    'Choisissez « Abonné Mobile Money »',
    'Entrez le numéro ci-dessus',
    'Entrez le montant',
    'Confirmez avec votre code PIN',
  ];

  static const _etapesAirtel = [
    'Composez *555#',
    'Choisissez « Envoyer de l\'argent »',
    'Entrez le numéro ci-dessus',
    'Entrez le montant',
    'Confirmez avec votre code PIN',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    // Couleur de l'opérateur : repère visuel (icônes, bordure). Elle ne porte
    // plus de texte — l'ambre MTN sous du blanc tombait autour de 2:1.
    final rawMethodColor = isMtn ? Colors.amber.shade700 : Colors.red.shade600;
    final methodColor = isDark
        ? Color.lerp(rawMethodColor, Colors.white, 0.45)!
        : rawMethodColor;
    final etapes = isMtn ? _etapesMtn : _etapesAirtel;

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: LiliaRadius.lgAll),
      title: Row(
        children: [
          Icon(Icons.payment, color: methodColor, size: 24),
          const SizedBox(width: LiliaSpacing.sm),
          const Expanded(
            child: Text(
              'Instructions de paiement',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pour valider votre commande, effectuez le paiement via '
              '$methodLabel :',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: LiliaSpacing.md),
            _CopiableField(
              label: 'Numéro $methodLabel',
              value: paymentPhoneNumber,
              valueStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              copyTooltip: 'Copier le numéro',
              copiedMessage: 'Numéro copié',
              background: methodColor.withValues(alpha: isDark ? 0.15 : 0.08),
              border: methodColor.withValues(alpha: 0.3),
              iconColor: methodColor,
            ),
            const SizedBox(height: LiliaSpacing.sp3),
            // Montant — celui de la commande créée, pas un recalcul client.
            Semantics(
              label: 'Montant à envoyer : ${formatPrice(amountDue)}',
              excludeSemantics: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LiliaSpacing.sp3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: LiliaRadius.smAll,
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Montant : ', style: TextStyle(fontSize: 14)),
                    Text(
                      formatPrice(amountDue),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.successText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (reference.isNotEmpty) ...[
              const SizedBox(height: LiliaSpacing.sp3),
              // Référence : seul moyen fiable pour l'admin de rapprocher un
              // virement d'une commande.
              _CopiableField(
                label: 'Référence à rappeler',
                value: reference,
                valueStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                copyTooltip: 'Copier la référence',
                copiedMessage: 'Référence copiée',
                background: cs.surfaceContainerHighest,
                iconColor: methodColor,
              ),
            ],
            const SizedBox(height: LiliaSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LiliaSpacing.sp3),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: LiliaRadius.smAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Étapes :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: LiliaSpacing.sm),
                  for (final (i, etape) in etapes.indexed)
                    Text(
                      '${i + 1}. $etape',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // La commande existe déjà : « Plus tard » ne l'annule pas, elle reste
        // payable depuis « Mes commandes » jusqu'à expiration.
        TextButton(onPressed: onLater, child: const Text('Plus tard')),
        // Style d'action du thème (`actionPrimary` + `textOnAction`) et non
        // la couleur de l'opérateur : blanc sur ambre MTN ≈ 2:1.
        ElevatedButton(onPressed: onPaid, child: const Text('J\'ai payé')),
      ],
    );
  }
}

class _CopiableField extends StatelessWidget {
  const _CopiableField({
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.copyTooltip,
    required this.copiedMessage,
    required this.background,
    required this.iconColor,
    this.border,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final String copyTooltip;
  final String copiedMessage;
  final Color background;
  final Color iconColor;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(LiliaSpacing.sp3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: LiliaRadius.smAll,
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '$label : $value',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: LiliaSpacing.xs),
                  Text(value, style: valueStyle.copyWith(color: cs.onSurface)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, color: iconColor),
            tooltip: copyTooltip,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              context.showSnack(copiedMessage);
            },
          ),
        ],
      ),
    );
  }
}
