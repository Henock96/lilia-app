// P3-10 — garde : les fautes d'accent corrigées ne reviennent pas dans les
// chaînes affichées. Liste fermée (les mots déjà rencontrés), pas un
// correcteur orthographique.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _fautes = RegExp(
  r"'[^']*\b(Epuise|Resume de|supplementaires|enregistrees?|apparaitront|"
  r"Parraines|Recompenses|premiere|Decouvrez|reunis|preferes|Selectionnez|"
  r"Code copie)\b[^']*'",
);

void main() {
  test('aucune faute d\'accent connue dans les chaînes de lib/', () {
    final fautes = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final l = lignes[i].trimLeft();
        if (l.startsWith('//') || l.contains('logDebug(')) continue;
        if (_fautes.hasMatch(l)) fautes.add('${f.path}:${i + 1}: $l');
      }
    }
    expect(fautes, isEmpty, reason: fautes.join('\n'));
  });
}
