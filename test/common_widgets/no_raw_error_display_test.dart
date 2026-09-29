// P3-05 — garde : aucun écran n'affiche une exception brute.
//
// `e.toString()`, `'Erreur: $e'`, `Text('$error')` exposaient au client des
// noms de classes Dart, des URL internes ou le message anglais d'un 500. Tout
// passe par `userFacingErrorMessage`. Ce test balaie `lib/` : un nouveau site
// fautif le fait échouer avec son emplacement.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _interdits = <RegExp>[
  RegExp(r"showErrorSnack\(\s*(e|err|error)\.toString\(\)"),
  RegExp(r"showErrorSnack\(\s*'[^']*\$\{?(e|err|error)\b"),
  RegExp(r"Text\(\s*'[^']*\$\{?(e|err|error)\b[^']*'"),
  RegExp(r"_error\s*=\s*(e|err|error)\.toString\(\)"),
  RegExp(r"(e|err|error)\.toString\(\)\.(contains|replaceFirst)\("),
];

void main() {
  test('aucune exception brute affichée dans lib/', () {
    final fautes = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final l = lignes[i];
        if (l.trimLeft().startsWith('//')) continue;
        if (_interdits.any((r) => r.hasMatch(l))) {
          fautes.add('${f.path}:${i + 1}: ${l.trim()}');
        }
      }
    }
    expect(fautes, isEmpty, reason: fautes.join('\n'));
  });
}
