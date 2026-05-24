import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';

enum LiliaBadgeVariant {
  primary, success, warning, danger, info, neutral, open, closed,
  pending, confirmed, preparing, ready, enRoute, delivered, cancelled,
}

class LiliaBadge extends StatelessWidget {
  const LiliaBadge({
    super.key,
    required this.label,
    this.variant = LiliaBadgeVariant.neutral,
    this.dot = false,
  });

  final String label;
  final LiliaBadgeVariant variant;
  final bool dot;

  static LiliaBadgeVariant fromOrderStatus(String status) => switch (status) {
    'PENDING_PAYMENT' => LiliaBadgeVariant.pending,
    'CONFIRMED'       => LiliaBadgeVariant.confirmed,
    'PREPARING'       => LiliaBadgeVariant.preparing,
    'READY'           => LiliaBadgeVariant.ready,
    'ASSIGNED'        => LiliaBadgeVariant.confirmed,
    'EN_ROUTE'        => LiliaBadgeVariant.enRoute,
    'DELIVERED'       => LiliaBadgeVariant.delivered,
    'CANCELLED'       => LiliaBadgeVariant.cancelled,
    _                 => LiliaBadgeVariant.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = _colors(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: LiliaRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  (Color bg, Color fg) _colors(bool isDark) => switch (variant) {
    LiliaBadgeVariant.primary   => (LiliaColors.orange500.withValues(alpha: 0.12), isDark ? LiliaColors.orange400 : LiliaColors.orange500),
    LiliaBadgeVariant.success   => (LiliaColors.green400.withValues(alpha: 0.15),  isDark ? const Color(0xFF4DC280) : LiliaColors.green400),
    LiliaBadgeVariant.warning   => (LiliaColors.amber400.withValues(alpha: 0.15),  isDark ? LiliaColors.amber300 : LiliaColors.amber400),
    LiliaBadgeVariant.danger    => (LiliaColors.red400.withValues(alpha: 0.12),    isDark ? LiliaColors.red300 : LiliaColors.red400),
    LiliaBadgeVariant.info      => (LiliaColors.blue500.withValues(alpha: 0.12),   isDark ? LiliaColors.blue300 : LiliaColors.blue500),
    LiliaBadgeVariant.open      => (LiliaColors.green400.withValues(alpha: 0.15),  isDark ? const Color(0xFF4DC280) : LiliaColors.green500),
    LiliaBadgeVariant.closed    => (LiliaColors.red400.withValues(alpha: 0.12),    isDark ? LiliaColors.red300 : LiliaColors.red400),
    LiliaBadgeVariant.pending   => (LiliaColors.amber400.withValues(alpha: 0.15),  isDark ? LiliaColors.amber300 : LiliaColors.amber400),
    LiliaBadgeVariant.confirmed => (LiliaColors.blue500.withValues(alpha: 0.12),   isDark ? LiliaColors.blue300 : LiliaColors.blue500),
    LiliaBadgeVariant.preparing => (LiliaColors.orange500.withValues(alpha: 0.12), isDark ? LiliaColors.orange400 : LiliaColors.orange500),
    LiliaBadgeVariant.ready     => (LiliaColors.green400.withValues(alpha: 0.12),  isDark ? const Color(0xFF4DC280) : LiliaColors.green500),
    LiliaBadgeVariant.enRoute   => (LiliaColors.orange500.withValues(alpha: 0.12), isDark ? LiliaColors.orange400 : LiliaColors.orange500),
    LiliaBadgeVariant.delivered => (LiliaColors.green400.withValues(alpha: 0.15),  isDark ? const Color(0xFF4DC280) : LiliaColors.green500),
    LiliaBadgeVariant.cancelled => (LiliaColors.red400.withValues(alpha: 0.12),    isDark ? LiliaColors.red300 : LiliaColors.red400),
    LiliaBadgeVariant.neutral   => (isDark ? LiliaColors.darkMuted : LiliaColors.cream200, isDark ? LiliaColors.charcoal300 : LiliaColors.charcoal500),
  };
}
