import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';

/// Intention sémantique d'un badge — jamais une couleur.
///
/// ⚠️ Les variantes « statut de commande » (`pending`, `confirmed`,
/// `delivered`…) et `fromOrderStatus` ont été retirées le 28/09/2026 : elles
/// n'avaient aucun appelant et mappaient `CONFIRMED`, `DELIVERED`, `READY`…,
/// des statuts que l'API n'émet pas (elle émet `EN_ATTENTE`, `PAYER`,
/// `LIVRER`…). C'était le piège déjà retiré de `LiliaOrderStatus`.
enum LiliaBadgeVariant { primary, success, warning, danger, info, neutral }

/// Pastille de statut du design system.
///
/// Toujours un **libellé**, et de préférence une [icon] : un statut ne se lit
/// jamais à sa seule couleur (daltonisme, écran en plein soleil, TalkBack).
class LiliaBadge extends StatelessWidget {
  const LiliaBadge({
    super.key,
    required this.label,
    this.variant = LiliaBadgeVariant.neutral,
    this.icon,
    this.dot = false,
  });

  final String label;
  final LiliaBadgeVariant variant;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = liliaBadgeColors(variant, isDark: isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: LiliaRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: LiliaSpacing.xs),
          ] else if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: LiliaSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fond et texte d'un badge. Exposé pour `test/theme/contrast_test.dart`.
///
/// En clair, le texte prend une teinte **foncée** de la famille : les teintes
/// de marque (orange500, green400, amber400, red400) posées sur leur propre
/// voile ne donnaient que 2.2 à 3.9:1 — sous le seuil AA, pour un texte de
/// 11 px. En sombre, les teintes claires passent déjà (≥ 4.9:1).
(Color bg, Color fg) liliaBadgeColors(
  LiliaBadgeVariant variant, {
  required bool isDark,
}) => switch (variant) {
  LiliaBadgeVariant.primary => (
    LiliaColors.orange500.withValues(alpha: 0.12),
    isDark ? LiliaColors.orange400 : LiliaColors.orange700,
  ),
  LiliaBadgeVariant.success => (
    LiliaColors.green400.withValues(alpha: 0.15),
    isDark ? const Color(0xFF4DC280) : LiliaColors.green700,
  ),
  LiliaBadgeVariant.warning => (
    LiliaColors.amber400.withValues(alpha: 0.15),
    isDark ? LiliaColors.amber300 : LiliaColors.amber700,
  ),
  LiliaBadgeVariant.danger => (
    LiliaColors.red400.withValues(alpha: 0.12),
    isDark ? LiliaColors.red300 : LiliaColors.red500,
  ),
  LiliaBadgeVariant.info => (
    LiliaColors.blue500.withValues(alpha: 0.12),
    isDark ? LiliaColors.blue300 : LiliaColors.blue500,
  ),
  LiliaBadgeVariant.neutral => (
    isDark ? LiliaColors.darkMuted : LiliaColors.cream200,
    isDark ? LiliaColors.charcoal300 : LiliaColors.charcoal500,
  ),
};
