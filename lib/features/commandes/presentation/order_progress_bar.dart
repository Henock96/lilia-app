import 'package:flutter/material.dart';
import 'package:lilia_app/models/order.dart';

class OrderProgressBar extends StatelessWidget {
  final OrderStatus status;

  const OrderProgressBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = ['Confirmée', 'En préparation', 'Prête', 'En route'];
    int currentStep = 0;

    switch (status) {
      case OrderStatus.enAttente:
        currentStep = 0;
        break;
      case OrderStatus.enPreparation:
        currentStep = 1;
        break;
      case OrderStatus.pret:
        currentStep = 2;
        break;
      case OrderStatus.enRoute:
        currentStep = 3;
        break;
      default:
        currentStep = 0;
    }

    final cs = Theme.of(context).colorScheme;
    final activeColor = cs.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepIndex < currentStep
                    ? activeColor
                    : cs.outline.withValues(alpha: 0.3),
              ),
            );
          } else {
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex <= currentStep;
            final isCurrent = stepIndex == currentStep;

            return Column(
              children: [
                Container(
                  width: isCurrent ? 16 : 12,
                  height: isCurrent ? 16 : 12,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? activeColor
                        : cs.outline.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: activeColor, width: 2)
                        : null,
                  ),
                  child: isCompleted && !isCurrent
                      ? const Icon(Icons.check, size: 8, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? activeColor : cs.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }
}
