import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/features/commandes/presentation/progress_step.dart';
import 'package:lilia_app/models/order.dart';

class OrderProgressStepper extends StatelessWidget {
  final OrderStatus status;

  const OrderProgressStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = [
      ProgressStep(
        icon: Iconsax.tick_circle,
        label: 'Confirmée',
        isCompleted: status != OrderStatus.enAttente,
        isCurrent: status == OrderStatus.enAttente,
      ),
      ProgressStep(
        icon: Iconsax.cake,
        label: 'En préparation',
        isCompleted:
            status == OrderStatus.pret ||
            status == OrderStatus.enRoute ||
            status == OrderStatus.livrer,
        isCurrent: status == OrderStatus.enPreparation,
      ),
      ProgressStep(
        icon: Iconsax.box_tick,
        label: 'Prête',
        isCompleted:
            status == OrderStatus.enRoute || status == OrderStatus.livrer,
        isCurrent: status == OrderStatus.pret,
      ),
      ProgressStep(
        icon: Iconsax.truck_fast,
        label: 'En route',
        isCompleted: status == OrderStatus.livrer,
        isCurrent: status == OrderStatus.enRoute,
      ),
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isCompleted =
              steps[stepIndex].isCompleted || steps[stepIndex].isCurrent;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green
                    : cs.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        } else {
          final step = steps[index ~/ 2];
          return _buildStepItem(context, step);
        }
      }),
    );
  }

  Widget _buildStepItem(BuildContext context, ProgressStep step) {
    final cs = Theme.of(context).colorScheme;
    final color = step.isCompleted || step.isCurrent
        ? Colors.green
        : cs.outline;

    return Column(
      children: [
        Container(
          width: step.isCurrent ? 44 : 36,
          height: step.isCurrent ? 44 : 36,
          decoration: BoxDecoration(
            color: step.isCompleted || step.isCurrent
                ? Colors.green.withValues(alpha: 0.1)
                : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: step.isCurrent
                ? Border.all(color: Colors.green, width: 2)
                : null,
          ),
          child: Icon(step.icon, size: step.isCurrent ? 22 : 18, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: step.isCurrent ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
