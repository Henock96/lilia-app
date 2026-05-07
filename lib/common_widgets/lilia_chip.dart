import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';

class LiliaFilterChip extends StatelessWidget {
  const LiliaFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.actionPrimary.withValues(alpha: 0.1) : t.bgElevated,
          borderRadius: LiliaRadius.pillAll,
          border: Border.all(
            color: selected ? t.actionPrimary : t.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(size: 14, color: selected ? t.actionPrimary : t.textSecondary),
                child: icon!,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? t.actionPrimary : t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiliaCategoryChip extends StatelessWidget {
  const LiliaCategoryChip({
    super.key,
    required this.emoji,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final String emoji;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? t.actionPrimary : t.actionPrimary.withValues(alpha: 0.1),
              boxShadow: active
                  ? [BoxShadow(color: t.actionPrimary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 60,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? t.actionPrimary : t.textMuted,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
