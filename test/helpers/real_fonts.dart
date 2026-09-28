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
/// débordement qui n'existe pas. Les polices sont variables : chaque graisse
/// est servie par le même fichier — métriques proches du réel, pas exactes.
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
  for (final MapEntry(key: famille, value: chemin) in familles.entries) {
    final octets = File(chemin).readAsBytesSync();
    Future<ByteData> donnees() async => ByteData.view(octets.buffer);
    await (FontLoader(famille)..addFont(donnees())).load();
    for (final v in variantes) {
      await (FontLoader('${famille}_$v')..addFont(donnees())).load();
    }
  }
}
