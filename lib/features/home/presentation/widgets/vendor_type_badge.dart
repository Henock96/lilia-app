import 'package:flutter/material.dart';
import 'package:lilia_app/models/vendor_type.dart';

/// Petit badge discret pour signaler le type de vendeur sur une carte
/// (LIL-117). Utilisé sur les cartes restaurant et le détail vendeur.
/// Pas affiché pour RESTAURANT (= défaut, ne pollue pas l'UI historique).
class VendorTypeBadge extends StatelessWidget {
  final VendorType vendorType;
  final bool compact;

  const VendorTypeBadge({
    super.key,
    required this.vendorType,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (vendorType == VendorType.RESTAURANT) {
      return const SizedBox.shrink();
    }
    final colors = _colorsFor(vendorType);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: colors.fg.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(vendorType.emoji, style: TextStyle(fontSize: compact ? 10 : 11)),
          SizedBox(width: compact ? 3 : 4),
          Text(
            compact ? vendorType.shortLabel : vendorType.label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: colors.fg,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _colorsFor(VendorType t) {
    switch (t) {
      case VendorType.HOME_COOK:
        return const _BadgeColors(bg: Color(0xFFFCE4EC), fg: Color(0xFFC2185B));
      case VendorType.BAKERY:
        return const _BadgeColors(bg: Color(0xFFFFF3E0), fg: Color(0xFFE65100));
      case VendorType.BEVERAGE_SHOP:
        return const _BadgeColors(bg: Color(0xFFE0F7FA), fg: Color(0xFF006064));
      case VendorType.GROCERY:
        return const _BadgeColors(bg: Color(0xFFE8F5E9), fg: Color(0xFF1B5E20));
      case VendorType.RESTAURANT:
        return const _BadgeColors(bg: Color(0xFFE3F2FD), fg: Color(0xFF0D47A1));
    }
  }
}

class _BadgeColors {
  final Color bg;
  final Color fg;
  const _BadgeColors({required this.bg, required this.fg});
}
