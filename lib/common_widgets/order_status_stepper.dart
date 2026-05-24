import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';

class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({
    super.key,
    required this.status,
  });

  final String status;

  static const _steps = [
    ('CONFIRMED', 'Confirmée'),
    ('PREPARING', 'Préparation'),
    ('READY',     'Prête'),
    ('EN_ROUTE',  'En route'),
    ('DELIVERED', 'Livrée'),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == 'CANCELLED' || status == 'PENDING_PAYMENT') return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;
    final currentStep = LiliaOrderStatus.stepIndex(status);

    return Column(
      children: [
        // Dots + lines
        Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Line
              final lineIndex = i ~/ 2;
              final done = lineIndex < currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2,
                  color: done ? t.actionPrimary : t.border,
                ),
              );
            }
            // Dot
            final dotIndex = i ~/ 2;
            final done    = dotIndex <= currentStep;
            final current = dotIndex == currentStep;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: done ? t.actionPrimary : t.bgMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? t.actionPrimary : t.border,
                  width: 1.5,
                ),
                boxShadow: current
                    ? [BoxShadow(color: t.actionPrimary.withValues(alpha: 0.25), blurRadius: 0, spreadRadius: 4)]
                    : null,
              ),
              child: Center(
                child: done && dotIndex < currentStep
                    ? Icon(Icons.check, size: 13, color: Colors.white)
                    : Text(
                        '${dotIndex + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: done ? Colors.white : t.textMuted,
                        ),
                      ),
              ),
            );
          }),
        ),

        const SizedBox(height: 6),

        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_steps.length, (i) {
            final active = i <= currentStep;
            return Text(
              _steps[i].$2,
              style: GoogleFonts.inter(
                fontSize: 9, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? t.actionPrimary : t.textMuted,
              ),
            );
          }),
        ),
      ],
    );
  }
}
