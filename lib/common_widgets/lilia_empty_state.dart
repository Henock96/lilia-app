import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';
import 'lilia_button.dart';

class LiliaEmptyState extends StatelessWidget {
  const LiliaEmptyState({
    super.key,
    this.icon,
    this.emoji,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData? icon;
  final String? emoji;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: t.actionPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: emoji != null
                    ? Text(emoji!, style: const TextStyle(fontSize: 34))
                    : Icon(icon ?? Icons.search_off_rounded,
                          size: 36, color: t.actionPrimary.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14, color: t.textMuted, height: 1.5,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              LiliaButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LiliaErrorState extends StatelessWidget {
  const LiliaErrorState({
    super.key,
    this.message,
    this.onRetry,
  });

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LiliaEmptyState(
    icon: Icons.wifi_off_rounded,
    title: 'Une erreur est survenue',
    subtitle: message ?? 'Vérifiez votre connexion et réessayez.',
    actionLabel: onRetry != null ? 'Réessayer' : null,
    onAction: onRetry,
  );
}
