import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lilia_tokens.dart';

// Helper: Fraunces display font for headings
TextStyle fraunces({
  double fontSize = 24,
  FontWeight fontWeight = FontWeight.w700,
  Color? color,
  double? height,
}) => GoogleFonts.fraunces(
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  height: height,
);

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(isDark: false);
  static ThemeData get dark => _build(isDark: true);

  // Backward-compat alias
  static ThemeData get theme => light;

  static ThemeData _build({required bool isDark}) {
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;
    final cs = isDark ? _darkColorScheme : _lightColorScheme;
    final base = GoogleFonts.oswaldTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: cs,

      // ── Typography ──────────────────────────────────────────────────────
      textTheme: base.copyWith(
        displayLarge: base.displayLarge?.copyWith(color: t.textPrimary),
        displayMedium: base.displayMedium?.copyWith(color: t.textPrimary),
        displaySmall: base.displaySmall?.copyWith(color: t.textPrimary),
        headlineLarge: base.headlineLarge?.copyWith(
          color: t.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          color: t.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          color: t.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.titleLarge?.copyWith(
          color: t.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.titleMedium?.copyWith(
          color: t.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: base.titleSmall?.copyWith(
          color: t.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: base.bodyLarge?.copyWith(color: t.textPrimary),
        bodyMedium: base.bodyMedium?.copyWith(color: t.textPrimary),
        bodySmall: base.bodySmall?.copyWith(color: t.textSecondary),
        labelLarge: base.labelLarge?.copyWith(
          color: t.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: base.labelMedium?.copyWith(color: t.textSecondary),
        labelSmall: base.labelSmall?.copyWith(color: t.textMuted),
      ),

      scaffoldBackgroundColor: t.bgPrimary,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: t.bgPrimary,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.girassol(
          fontSize: 19,
          fontWeight: FontWeight.w500,
          color: t.textPrimary,
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),

      // ── Bottom Nav ──────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.bgPrimary,
        selectedItemColor: t.actionPrimary,
        unselectedItemColor: t.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.bgPrimary,
        indicatorColor: t.actionPrimary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? t.actionPrimary : t.textMuted,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.oswald(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? t.actionPrimary : t.textMuted,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // ── ElevatedButton = Primary ────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.actionPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: t.actionPrimary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: GoogleFonts.oswald(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── OutlinedButton = Secondary ──────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.actionPrimary,
          side: BorderSide(color: t.actionPrimary, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: GoogleFonts.oswald(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── FilledButton = Ghost / Muted ────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.bgMuted,
          foregroundColor: t.textSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: LiliaRadius.mdAll),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.actionPrimary,
          textStyle: GoogleFonts.oswald(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.bgElevated,
        hintStyle: GoogleFonts.inter(fontSize: 15, color: t.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: LiliaRadius.mdAll,
          borderSide: BorderSide(color: t.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LiliaRadius.mdAll,
          borderSide: BorderSide(color: t.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LiliaRadius.mdAll,
          borderSide: BorderSide(color: t.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: LiliaRadius.mdAll,
          borderSide: BorderSide(color: t.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: LiliaRadius.mdAll,
          borderSide: BorderSide(color: t.danger, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: t.danger,
        ),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: t.bgElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LiliaRadius.lgAll,
          side: BorderSide(color: t.border, width: 1),
        ),
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: t.bgElevated,
        selectedColor: t.actionPrimary.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: t.textSecondary,
        ),
        side: BorderSide(color: t.border, width: 1.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 0),

      // ── SnackBar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? LiliaColors.charcoal600
            : LiliaColors.charcoal700,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        actionTextColor: t.actionPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: LiliaRadius.mdAll),
      ),

      // ── TabBar ──────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: t.actionPrimary,
        unselectedLabelColor: t.textMuted,
        indicatorColor: t.actionPrimary,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.oswald(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: t.border,
      ),

      // ── Switch ──────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : t.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.actionPrimary
              : t.bgMuted,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Checkbox ────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.actionPrimary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: t.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Radio ───────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.actionPrimary
              : t.textMuted,
        ),
      ),

      // ── ListTile ────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: t.textSecondary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: t.textPrimary,
        ),
        subtitleTextStyle: GoogleFonts.inter(fontSize: 12, color: t.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: t.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: LiliaRadius.xlAll),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: t.textPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: t.textSecondary,
        ),
      ),

      // ── BottomSheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LiliaRadius.xl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: t.border,
      ),

      // ── Progress ────────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.actionPrimary,
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.actionPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),

      // ── Page transitions ─────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: LiliaColors.orange500,
    onPrimary: Colors.white,
    primaryContainer: LiliaColors.orange100,
    onPrimaryContainer: LiliaColors.orange700,
    secondary: LiliaColors.blue500,
    onSecondary: Colors.white,
    secondaryContainer: LiliaColors.cream200,
    onSecondaryContainer: LiliaColors.charcoal700,
    tertiary: LiliaColors.green400,
    onTertiary: Colors.white,
    error: LiliaColors.red400,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: LiliaColors.charcoal700,
    surfaceContainerHighest: LiliaColors.cream200,
    outline: LiliaColors.charcoal100,
    outlineVariant: LiliaColors.charcoal200,
    shadow: LiliaColors.charcoal700,
    scrim: LiliaColors.charcoal700,
    inverseSurface: LiliaColors.charcoal700,
    onInverseSurface: LiliaColors.cream100,
    inversePrimary: LiliaColors.orange300,
  );

  static const _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: LiliaColors.orange400,
    onPrimary: Colors.white,
    primaryContainer: LiliaColors.orange700,
    onPrimaryContainer: LiliaColors.orange100,
    secondary: LiliaColors.blue300,
    onSecondary: LiliaColors.charcoal700,
    secondaryContainer: LiliaColors.darkMuted,
    onSecondaryContainer: LiliaColors.charcoal200,
    tertiary: Color(0xFF4DC280),
    onTertiary: Colors.white,
    error: LiliaColors.red300,
    onError: LiliaColors.charcoal700,
    surface: LiliaColors.darkSurface,
    onSurface: LiliaColors.charcoal50,
    surfaceContainerHighest: LiliaColors.darkMuted,
    outline: LiliaColors.darkBorder,
    outlineVariant: LiliaColors.charcoal600,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: LiliaColors.charcoal50,
    onInverseSurface: LiliaColors.charcoal700,
    inversePrimary: LiliaColors.orange600,
  );
}
