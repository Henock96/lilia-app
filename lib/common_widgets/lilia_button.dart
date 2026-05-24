import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';

enum LiliaButtonVariant { primary, secondary, ghost, danger, muted }

class LiliaButton extends StatelessWidget {
  const LiliaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = LiliaButtonVariant.primary,
    this.loading = false,
    this.fullWidth = true,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final LiliaButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final Widget? icon;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;
    final disabled = onPressed == null || loading;

    Widget child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_fgColor(variant, t)),
            ),
          )
        else ...[
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600,
              letterSpacing: -0.1, color: _fgColor(variant, t),
            ),
          ),
          if (trailingIcon != null) ...[const SizedBox(width: 8), trailingIcon!],
        ],
      ],
    );

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: _buildButton(variant, t, child, fullWidth, disabled ? null : onPressed),
    );
  }

  Widget _buildButton(
    LiliaButtonVariant v,
    LiliaThemeTokens t,
    Widget child,
    bool full,
    VoidCallback? onTap,
  ) {
    final shape = const StadiumBorder();
    final padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 15);
    final width = full ? double.infinity : null;

    switch (v) {
      case LiliaButtonVariant.primary:
        return SizedBox(
          width: width,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: t.actionPrimary,
              foregroundColor: Colors.white,
              elevation: 0, shadowColor: Colors.transparent,
              shape: shape, padding: padding,
            ),
            child: child,
          ),
        );

      case LiliaButtonVariant.secondary:
        return SizedBox(
          width: width,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: t.actionPrimary,
              side: BorderSide(color: t.actionPrimary, width: 1.5),
              shape: shape, padding: padding,
            ),
            child: child,
          ),
        );

      case LiliaButtonVariant.danger:
        return SizedBox(
          width: width,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
              elevation: 0, shadowColor: Colors.transparent,
              shape: shape, padding: padding,
            ),
            child: child,
          ),
        );

      case LiliaButtonVariant.ghost:
      case LiliaButtonVariant.muted:
        return SizedBox(
          width: width,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: t.bgMuted,
              foregroundColor: t.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: LiliaRadius.mdAll),
              padding: padding,
            ),
            child: child,
          ),
        );
    }
  }

  Color _fgColor(LiliaButtonVariant v, LiliaThemeTokens t) => switch (v) {
    LiliaButtonVariant.primary   => Colors.white,
    LiliaButtonVariant.secondary => t.actionPrimary,
    LiliaButtonVariant.danger    => Colors.white,
    _                            => t.textSecondary,
  };
}

// Backward-compat: PrimaryButton alias
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.isLoading = false,
    this.onPressed,
  });

  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => LiliaButton(
    label: text,
    loading: isLoading,
    onPressed: onPressed,
  );
}
