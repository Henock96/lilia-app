// La référence de commande venait d'un `substring(0, 8)` recopié à cinq
// endroits — et d'un `substring(length - 6)` au sixième.
//
// Deux conséquences : la même commande portait deux références selon l'écran,
// et l'un des cinq sites lisait une valeur venue d'une charge utile FCM, donc
// de l'extérieur. Un `orderId` court y produisait un `RangeError` sur l'écran
// des commandes.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/utils/order_reference.dart';

void main() {
  test('un cuid est tronqué à huit caractères, en majuscules', () {
    expect(refCommande('cmhz4k2p0000abcd1234efgh'), '#CMHZ4K2P');
  });

  test('deux écrans, une seule référence pour la même commande', () {
    // C'est l'invariant : le client cite ce qu'il voit, le support cherche ce
    // qu'il cite. Deux formats rendaient la commande introuvable.
    const id = 'cmhz4k2p0000abcd1234efgh';
    expect(refCommande(id), refCommande(id));
    expect(refCommande(id), startsWith('#'));
  });

  group('valeurs venues de l’extérieur — un push FCM n’est pas un contrat', () {
    test('un identifiant plus court que huit est rendu en entier', () {
      // `substring(0, 8)` levait ici. Mieux vaut une référence inhabituelle
      // qu'un écran des commandes qui plante.
      expect(refCommande('abc'), '#ABC');
      expect(refCommande('12345678'), '#12345678');
    });

    test('vide, blanc ou absent : un tiret, pas une exception', () {
      expect(refCommande(''), '#—');
      expect(refCommande('   '), '#—');
      expect(refCommande(null), '#—');
    });
  });
}
