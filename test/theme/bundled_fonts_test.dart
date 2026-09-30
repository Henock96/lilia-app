// Chaque police demandée via `google_fonts` doit exister dans le bundle, sous
// le nom exact que le paquet cherche (`Inter-SemiBold.ttf`).
//
// `allowRuntimeFetching = false` (main.dart) interdit le téléchargement. Avec
// les seules polices variables embarquées, chaque `GoogleFonts.inter(
// fontWeight: w600)` échouait sur l'appareil (« not found in the application
// assets ») et retombait sur la famille variable à sa graisse par défaut : le
// thème n'était jamais rendu avec ses graisses (constaté sur iPhone, Phase
// 3.7). Ce test casse si une graisse est ajoutée au code sans son fichier.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Variantes réellement demandées par `lib/` (thème Oswald de Material 3 :
/// 400 et 500 ; `GoogleFonts.oswald/inter` : 500, 600, 700 ; Girassol 500 →
/// seule variante publiée, Regular).
const _attendues = [
  'Inter-Regular',
  'Inter-Medium',
  'Inter-SemiBold',
  'Inter-Bold',
  'Oswald-Regular',
  'Oswald-Medium',
  'Oswald-SemiBold',
  'Girassol-Regular',
];

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final declarees = RegExp(
    r'- asset: (\S+\.ttf)',
  ).allMatches(pubspec).map((m) => m.group(1)!).toList();

  for (final nom in _attendues) {
    test('$nom.ttf est déclarée et présente', () {
      // Même règle que `findFamilyWithVariantAssetPath` de google_fonts.
      final chemin = declarees.where((a) => a.endsWith('$nom.ttf'));
      expect(chemin, isNotEmpty, reason: 'absente du pubspec');
      expect(File(chemin.first).existsSync(), isTrue, reason: chemin.first);
    });
  }

  test('le code ne demande pas de graisse Inter/Oswald hors du bundle', () {
    final graisses = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/generated/')) continue;
      final s = f.readAsStringSync();
      for (final m in RegExp(
        r'GoogleFonts\.(inter|oswald)\(([^;]*?)\)',
        dotAll: true,
      ).allMatches(s)) {
        final w = RegExp(r'FontWeight\.w(\d00)').firstMatch(m.group(2)!);
        graisses.add('${m.group(1)}:${w?.group(1) ?? '400'}');
      }
    }
    const couvertes = {'400', '500', '600', '700'};
    for (final g in graisses) {
      expect(couvertes, contains(g.split(':')[1]), reason: g);
    }
  });
}
