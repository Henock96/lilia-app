import 'dart:io';

import 'package:flutter/services.dart';

/// Charge les **vraies** polices embarquées (`assets/fonts/`) sous les noms de
/// famille que demande `google_fonts` (`Inter_regular`, `Inter_600`,
/// `Oswald_700`…), plus `Roboto` (police Material par défaut, approchée par
/// Inter).
///
/// Sans cela, `flutter_test` rend chaque glyphe comme un carré plein de la
/// taille de la police : « Passer la commande » y occupe ~340 dp au lieu de
/// ~140, et tout test de débordement à largeur de téléphone échoue sur un
/// débordement qui n'existe pas. Inter et Oswald sont servies par les
/// **statiques** embarquées dans l'application (400/500/600/700) — les mêmes
/// fichiers que sur l'appareil ; les autres graisses, et les autres familles,
/// par la police variable (métriques proches, pas exactes).
Future<void> chargerPolicesReelles() async {
  const familles = {
    'Inter': 'assets/fonts/inter/Inter-VariableFont.ttf',
    'Oswald': 'assets/fonts/oswald/Oswald-VariableFont.ttf',
    'Fraunces': 'assets/fonts/fraunces/Fraunces-VariableFont.ttf',
    'Girassol': 'assets/fonts/girassol/Girassol-Regular.ttf',
    'Roboto': 'assets/fonts/inter/Inter-VariableFont.ttf',
  };
  const variantes = [
    'regular', 'italic', '100', '200', '300', '500', '600', '700', '800', //
    '900',
  ];
  // Graisse `google_fonts` → statique embarquée (`pubspec.yaml`).
  const statiques = {
    'regular': 'Regular',
    '500': 'Medium',
    '600': 'SemiBold',
    '700': 'Bold',
  };
  ByteData lire(String chemin) =>
      ByteData.view(File(chemin).readAsBytesSync().buffer);
  String? statique(String famille, String variante) {
    final nom = statiques[variante];
    if (nom == null || (famille != 'Inter' && famille != 'Oswald')) {
      return null;
    }
    return 'assets/fonts/${famille.toLowerCase()}/static/$famille-$nom.ttf';
  }

  for (final MapEntry(key: famille, value: chemin) in familles.entries) {
    final variable = lire(chemin);
    final base = FontLoader(famille)..addFont(Future.value(variable));
    if (famille == 'Inter' || famille == 'Oswald') {
      for (final v in statiques.keys) {
        base.addFont(Future.value(lire(statique(famille, v)!)));
      }
    }
    await base.load();
    for (final v in variantes) {
      final fichier = statique(famille, v);
      await (FontLoader('${famille}_$v')
            ..addFont(Future.value(fichier == null ? variable : lire(fichier))))
          .load();
    }
  }
}
