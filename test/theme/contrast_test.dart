import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Ratio de contraste WCAG 2.x entre deux couleurs opaques.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// Seuil AA pour du texte de taille normale.
const double kAaNormalText = 4.5;

/// Les tokens portaient quatre combinaisons sous le seuil, dont la couleur de
/// fond de **tous** les boutons d'action (3.67:1 en clair, 2.84:1 en sombre).
/// Ces tests figent le résultat : toute régression de palette casse la CI.
void main() {
  group('Contrastes WCAG AA — thème clair', () {
    const t = LiliaSemantics.light;

    test('texte sur action principale', () {
      expect(
        contrastRatio(t.textOnAction, t.actionPrimary),
        greaterThanOrEqualTo(kAaNormalText),
      );
    });

    test('texte sur action au survol', () {
      expect(
        contrastRatio(t.textOnAction, t.actionHover),
        greaterThanOrEqualTo(kAaNormalText),
      );
    });

    test('textMuted sur les trois fonds', () {
      for (final bg in [t.bgPrimary, t.bgSecondary, t.bgMuted]) {
        expect(
          contrastRatio(t.textMuted, bg),
          greaterThanOrEqualTo(kAaNormalText),
          reason: 'textMuted porte bodySmall/labelSmall, souvent en 11 px',
        );
      }
    });

    test('textPrimary et textSecondary sur les fonds', () {
      for (final fg in [t.textPrimary, t.textSecondary]) {
        for (final bg in [t.bgPrimary, t.bgSecondary, t.bgMuted]) {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(kAaNormalText));
        }
      }
    });
  });

  group('Contrastes WCAG AA — thème sombre', () {
    const t = LiliaSemantics.dark;

    test('texte sur action principale', () {
      expect(
        contrastRatio(t.textOnAction, t.actionPrimary),
        greaterThanOrEqualTo(kAaNormalText),
      );
    });

    test('texte sur action au survol', () {
      expect(
        contrastRatio(t.textOnAction, t.actionHover),
        greaterThanOrEqualTo(kAaNormalText),
      );
    });

    test('textMuted sur les trois fonds', () {
      for (final bg in [t.bgPrimary, t.bgSecondary, t.bgElevated, t.bgMuted]) {
        expect(
          contrastRatio(t.textMuted, bg),
          greaterThanOrEqualTo(kAaNormalText),
        );
      }
    });

    test('textPrimary et textSecondary sur les fonds', () {
      for (final fg in [t.textPrimary, t.textSecondary]) {
        for (final bg in [t.bgPrimary, t.bgSecondary, t.bgElevated]) {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(kAaNormalText));
        }
      }
    });
  });

  /// Un badge est un voile translucide : son fond réel dépend de la surface
  /// où il est posé. Les teintes de marque sur leur propre voile tombaient
  /// entre 2.2 et 3.9:1 en clair — pour du texte de 11 px (stock, ouverture).
  group('Badges — texte sur voile, sur chaque surface', () {
    for (final isDark in [false, true]) {
      final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;
      for (final variant in LiliaBadgeVariant.values) {
        test('${isDark ? 'sombre' : 'clair'} — ${variant.name}', () {
          final (bg, fg) = liliaBadgeColors(variant, isDark: isDark);
          for (final surface in [t.bgPrimary, t.bgSecondary, t.bgElevated]) {
            expect(
              contrastRatio(fg, Color.alphaBlend(bg, surface)),
              greaterThanOrEqualTo(kAaNormalText),
              reason: 'sur $surface',
            );
          }
        });
      }
    }
  });

  group('Texte de feedback (remises, points) sur les surfaces', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final cs = theme.colorScheme;
      test(cs.brightness.name, () {
        for (final fg in [cs.successText, cs.warningText]) {
          for (final bg in [
            cs.surface,
            cs.surfaceContainerHighest,
            theme.scaffoldBackgroundColor,
          ]) {
            expect(
              contrastRatio(fg, bg),
              greaterThanOrEqualTo(kAaNormalText),
              reason: '$fg sur $bg',
            );
          }
        }
      });
    }
  });

  test('pastille ouvert / fermé posée sur photo : blanc lisible', () {
    for (final fond in [LiliaColors.green700, LiliaColors.red500]) {
      expect(
        contrastRatio(const Color(0xFFFFFFFF), fond),
        greaterThanOrEqualTo(kAaNormalText),
        reason: '$fond',
      );
    }
  });

  test('le calcul de ratio est correct sur les bornes connues', () {
    // Noir sur blanc = 21:1, blanc sur blanc = 1:1 — garde-fou du helper.
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
      closeTo(1, 0.001),
    );
  });
}
