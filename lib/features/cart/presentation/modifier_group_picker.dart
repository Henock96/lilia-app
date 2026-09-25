import 'package:flutter/material.dart';

import 'package:lilia_app/features/cart/domain/modifier_selection.dart';
import 'package:lilia_app/models/modifier.dart';
import 'package:lilia_app/utils/currency.dart';

/// F3-09 — sélecteur d'options d'une fiche produit.
///
/// ```
/// Accompagnement                         Obligatoire
///   ◉ Alloco                                  +500
///   ○ Frites
///   ○ Riz
/// Suppléments                          2 au maximum
///   ☑ Œuf            [−] 2 [+]               +300
///   ☐ Fromage                                +500
/// ```
///
/// - radio quand `maxSelect == 1`, cases à cocher sinon ;
/// - pas-à-pas de quantité quand l'option se prend plusieurs fois ;
/// - option en rupture : visible, grisée, « Épuisé » — jamais sélectionnable.
///
/// Composant **contrôlé** : l'état vit dans [ModifierSelectionState], possédé
/// par l'écran, qui recalcule son prix et son bouton à chaque [onChanged].
class ModifierGroupPicker extends StatelessWidget {
  const ModifierGroupPicker({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final ModifierSelectionState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in state.groups)
          _GroupSection(group: group, state: state, onChanged: onChanged),
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.state,
    required this.onChanged,
  });

  final ModifierGroup group;
  final ModifierSelectionState state;
  final VoidCallback onChanged;

  String get _rule {
    if (group.isRequired) {
      return group.minSelect == group.maxSelect
          ? (group.minSelect == 1
                ? 'Obligatoire'
                : 'Obligatoire · ${group.minSelect} choix')
          : 'Obligatoire · ${group.minSelect} à ${group.maxSelect} choix';
    }
    return group.isSingleChoice
        ? 'Facultatif'
        : 'Facultatif · ${group.maxSelect} au maximum';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final incomplete = state.firstIncompleteGroup?.id == group.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _rule,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: incomplete ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final option in group.options)
            _OptionTile(
              group: group,
              option: option,
              state: state,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.group,
    required this.option,
    required this.state,
    required this.onChanged,
  });

  final ModifierGroup group;
  final ModifierOption option;
  final ModifierSelectionState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = state.isSelected(option.id);
    final enabled = option.isAvailable;
    final quantity = state.quantityOf(option.id);

    final control = group.isSingleChoice
        ? Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? cs.primary : cs.outline,
          )
        : Icon(
            selected ? Icons.check_box : Icons.check_box_outline_blank,
            color: selected ? cs.primary : cs.outline,
          );

    return Semantics(
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: group.isSingleChoice,
      label: option.name,
      child: InkWell(
        key: ValueKey('modifier-option-${option.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () {
                if (state.toggle(group, option)) {
                  onChanged();
                } else {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        '« ${group.name} » : ${group.maxSelect} choix au maximum.',
                      ),
                    ),
                  );
                }
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                control,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      decoration: enabled ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
                if (!enabled)
                  Text(
                    'Épuisé',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  )
                else ...[
                  if (selected && option.maxQuantity > 1)
                    _Stepper(
                      quantity: quantity,
                      max: option.maxQuantity,
                      onChanged: (q) {
                        state.setQuantity(option, q);
                        onChanged();
                      },
                    ),
                  if (option.priceDeltaXaf > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '+${formatAmount(option.priceDeltaXaf)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Moins',
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Plus',
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
        ),
      ],
    );
  }
}
