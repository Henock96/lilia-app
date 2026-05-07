import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';

class LiliaQuantityStepper extends StatelessWidget {
  const LiliaQuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          active: canDecrement,
          onTap: canDecrement ? () => onChanged(value - 1) : null,
          bg: canDecrement
              ? t.actionPrimary.withValues(alpha: 0.15)
              : t.bgMuted,
          color: canDecrement ? t.actionPrimary : t.textMuted,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w700, color: t.textPrimary,
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          active: canIncrement,
          onTap: canIncrement ? () => onChanged(value + 1) : null,
          bg: canIncrement ? t.actionPrimary : t.bgMuted,
          color: canIncrement ? Colors.white : t.textMuted,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.bg,
    required this.color,
  });

  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34, height: 34,
        decoration: BoxDecoration(color: bg, borderRadius: LiliaRadius.smAll),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
