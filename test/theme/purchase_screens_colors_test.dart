// Écrans d'achat : aucune couleur brute de Material (UX-03, audit du
// 06/11/2026).
//
// `Colors.amber` sur crème tombait à 1,63:1, `Colors.green` sur `green[100]`
// à 2,07:1, `Colors.orange` à 2,16:1 — et aucune ne suit le mode sombre. Les
// variantes « texte » du thème (`successText`, `warningText`, `error`,
// `onSurfaceVariant`) sont calculées pour le contraste dans les deux modes
// (`contrast_test.dart`). `Colors.white` / `black` / `transparent` restent
// permis : ce ne sont pas des teintes de la palette Material.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _ecransDAchat = [
  'lib/features/home/presentation/restaurant_detail_screen.dart',
  'lib/features/home/presentation/menu_detail_page.dart',
  'lib/features/home/presentation/product_detail_page.dart',
  'lib/features/cart/presentation/cart_screen.dart',
  'lib/features/commandes/presentation/checkout_page.dart',
];

// `\b` : `LiliaColors.orange400` (la palette de la marque) n'est pas visé.
final _teinteBrute = RegExp(
  r'\bColors\.(red|pink|purple|deepPurple|indigo|blue|lightBlue|cyan|teal|green|'
  r'lightGreen|lime|yellow|amber|orange|deepOrange|brown|grey|blueGrey)'
  r'(Accent)?\b',
);

void main() {
  for (final chemin in _ecransDAchat) {
    test('$chemin n’emploie que les couleurs du thème', () {
      final lignes = File(chemin).readAsLinesSync();
      final fautives = <String>[
        for (var i = 0; i < lignes.length; i++)
          if (_teinteBrute.hasMatch(lignes[i]) &&
              !lignes[i].trimLeft().startsWith('//'))
            '${i + 1}: ${lignes[i].trim()}',
      ];
      expect(fautives, isEmpty, reason: fautives.join('\n'));
    });
  }
}
