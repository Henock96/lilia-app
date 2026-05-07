import 'package:flutter/material.dart';

// ─── Primitive colors ────────────────────────────────────────────────────────

class LiliaColors {
  LiliaColors._();

  // Orange brand
  static const orange50  = Color(0xFFFFF4EF);
  static const orange100 = Color(0xFFFFE4D3);
  static const orange200 = Color(0xFFFFC5A1);
  static const orange300 = Color(0xFFFF9E6A);
  static const orange400 = Color(0xFFF47430);
  static const orange500 = Color(0xFFE8541F); // brand primary
  static const orange600 = Color(0xFFC8421A);
  static const orange700 = Color(0xFF9E3012);
  static const orange800 = Color(0xFF742009);

  // Cream
  static const cream50  = Color(0xFFFFFDF9);
  static const cream100 = Color(0xFFFAF5EE); // bg primary light
  static const cream200 = Color(0xFFF3E8D8);
  static const cream300 = Color(0xFFE8D5BC);

  // Charcoal
  static const charcoal50  = Color(0xFFF6F4F2);
  static const charcoal100 = Color(0xFFE9E4DF);
  static const charcoal200 = Color(0xFFCEC7BF);
  static const charcoal300 = Color(0xFFABA39A);
  static const charcoal400 = Color(0xFF7A726A);
  static const charcoal500 = Color(0xFF4D4540);
  static const charcoal600 = Color(0xFF352E2A);
  static const charcoal700 = Color(0xFF1C1815); // text primary light
  static const charcoal800 = Color(0xFF0F0D0B); // bg primary dark

  // Blue encre (secondary)
  static const blue300 = Color(0xFF6A9ABF);
  static const blue400 = Color(0xFF3D6F96);
  static const blue500 = Color(0xFF2B4A6B);

  // Semantic feedback
  static const green400  = Color(0xFF27A660);
  static const green500  = Color(0xFF1A8A4A);
  static const amber300  = Color(0xFFF5C44A);
  static const amber400  = Color(0xFFD4970A);
  static const red300    = Color(0xFFF4826E);
  static const red400    = Color(0xFFD63F28);

  // Dark mode surfaces
  static const darkBg      = Color(0xFF0F0D0B);
  static const darkSurface = Color(0xFF1C1815);
  static const darkCard    = Color(0xFF252018);
  static const darkMuted   = Color(0xFF2A2318);
  static const darkBorder  = Color(0xFF352E2A);
}

// ─── Semantic tokens ─────────────────────────────────────────────────────────

class LiliaSemantics {
  LiliaSemantics._();

  // Light
  static const light = LiliaThemeTokens(
    bgPrimary:       LiliaColors.cream100,
    bgSecondary:     Colors.white,
    bgElevated:      Colors.white,
    bgMuted:         LiliaColors.cream200,
    textPrimary:     LiliaColors.charcoal700,
    textSecondary:   LiliaColors.charcoal500,
    textMuted:       LiliaColors.charcoal400,
    textInverse:     Colors.white,
    actionPrimary:   LiliaColors.orange500,
    actionHover:     LiliaColors.orange600,
    border:          LiliaColors.charcoal100,
    borderFocus:     LiliaColors.orange500,
    success:         LiliaColors.green400,
    warning:         LiliaColors.amber400,
    danger:          LiliaColors.red400,
    info:            LiliaColors.blue500,
  );

  // Dark
  static const dark = LiliaThemeTokens(
    bgPrimary:       LiliaColors.darkBg,
    bgSecondary:     LiliaColors.darkSurface,
    bgElevated:      LiliaColors.darkCard,
    bgMuted:         LiliaColors.darkMuted,
    textPrimary:     LiliaColors.charcoal50,
    textSecondary:   LiliaColors.charcoal200,
    textMuted:       LiliaColors.charcoal400,
    textInverse:     LiliaColors.charcoal700,
    actionPrimary:   LiliaColors.orange400,
    actionHover:     LiliaColors.orange300,
    border:          LiliaColors.darkBorder,
    borderFocus:     LiliaColors.orange400,
    success:         Color(0xFF4DC280),
    warning:         LiliaColors.amber300,
    danger:          LiliaColors.red300,
    info:            LiliaColors.blue300,
  );
}

class LiliaThemeTokens {
  const LiliaThemeTokens({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgElevated,
    required this.bgMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.actionPrimary,
    required this.actionHover,
    required this.border,
    required this.borderFocus,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgElevated;
  final Color bgMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textInverse;
  final Color actionPrimary;
  final Color actionHover;
  final Color border;
  final Color borderFocus;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
}

// ─── Spacing ─────────────────────────────────────────────────────────────────

class LiliaSpacing {
  LiliaSpacing._();

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  // Named aliases matching the HTML prototype
  static const double sp1  = 4;
  static const double sp2  = 8;
  static const double sp3  = 12;
  static const double sp4  = 16;
  static const double sp5  = 20;
  static const double sp6  = 24;
  static const double sp8  = 32;
  static const double sp10 = 40;
  static const double sp12 = 48;

  static const double screenH = 20; // horizontal screen padding
}

// ─── Radius ──────────────────────────────────────────────────────────────────

class LiliaRadius {
  LiliaRadius._();

  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 28;
  static const double pill = 999;

  static const BorderRadius smAll   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll  = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

// ─── OrderStatus helpers ──────────────────────────────────────────────────────

class LiliaOrderStatus {
  LiliaOrderStatus._();

  static String label(String status) => switch (status) {
    'PENDING_PAYMENT' => 'En attente de paiement',
    'CONFIRMED'       => 'Confirmée',
    'PREPARING'       => 'En préparation',
    'READY'           => 'Prête',
    'ASSIGNED'        => 'Livreur assigné',
    'EN_ROUTE'        => 'En route',
    'DELIVERED'       => 'Livrée',
    'CANCELLED'       => 'Annulée',
    _                 => status,
  };

  static Color color(String status, {bool dark = false}) => switch (status) {
    'PENDING_PAYMENT'        => dark ? LiliaColors.amber300 : LiliaColors.amber400,
    'CONFIRMED' || 'ASSIGNED'=> dark ? LiliaColors.blue300  : LiliaColors.blue500,
    'PREPARING'              => dark ? LiliaColors.orange400 : LiliaColors.orange500,
    'READY'                  => dark ? const Color(0xFF4DC280) : LiliaColors.green400,
    'EN_ROUTE'               => dark ? LiliaColors.orange400 : LiliaColors.orange500,
    'DELIVERED'              => dark ? const Color(0xFF4DC280) : LiliaColors.green400,
    'CANCELLED'              => dark ? LiliaColors.red300 : LiliaColors.red400,
    _                        => dark ? LiliaColors.charcoal300 : LiliaColors.charcoal400,
  };

  static int stepIndex(String status) => switch (status) {
    'CONFIRMED'  => 0,
    'PREPARING'  => 1,
    'READY'      => 2,
    'ASSIGNED'   => 2,
    'EN_ROUTE'   => 3,
    'DELIVERED'  => 4,
    _            => -1,
  };
}

// ─── formatCurrency ───────────────────────────────────────────────────────────

String liliaFormatPrice(num amount) {
  final formatted = amount.toInt().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
  return '$formatted FCFA';
}
