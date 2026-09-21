// La sortie des écrans d'authentification, éprouvée destination par
// destination.
//
// Le mode visiteur tient à ce que l'écran de connexion ne soit pas un cul-de-sac.
// Comme la pile est vide à l'arrivée (le `redirect` REMPLACE l'emplacement), le
// retour ne peut pas dépiler : il calcule. C'est ce calcul qui est testé ici —
// sans widget, sans routeur, comme `resolveRedirect` et `sanitizeDestination`.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/routing/auth_exit.dart';

void main() {
  group('remonte au premier emplacement public', () {
    const cas = <String, String>{
      // LE cas qui motive tout : le visiteur bute sur les options de livraison,
      // il doit retrouver son panier — pas l'accueil, et surtout pas la sortie.
      '/cart/delivery-options': '/cart',
      '/cart/delivery-options/checkout': '/cart',
      // Lire les avis reste public ; en écrire un ne l'est pas.
      '/reviews/resto-1/write': '/reviews/resto-1',
      // La requête décrit l'écran demandé : elle ne suit pas sur le parent.
      '/cart/delivery-options?mode=express': '/cart',
    };

    cas.forEach((demandee, attendue) {
      test('$demandee → $attendue', () {
        expect(publicExitFor(demandee), attendue);
      });
    });
  });

  group("retombe sur l'accueil quand rien de public ne surplombe", () {
    const versAccueil = <String>[
      '/commandes',
      '/commandes/abc',
      '/commandes/abc/tracking',
      '/profile',
      '/profile/address',
      '/profile/favoris/details',
      '/order-success',
      '/notifications',
    ];

    for (final demandee in versAccueil) {
      test('$demandee → /', () {
        expect(publicExitFor(demandee), '/');
      });
    }
  });

  group('destination absente ou refusée → accueil', () {
    // Les mêmes refus que `sanitizeDestination` : une destination qu'on ne
    // peut pas router n'est pas une erreur, c'est simplement « rien à
    // restaurer ». L'accueil est alors la bonne réponse, jamais un écran vide.
    const refusees = <String?>[
      null,
      '',
      '   ',
      'https://exemple.com/cart', // redirection ouverte
      '//exemple.com/cart', // même chose, forme relative au protocole
      'cart/delivery-options', // chemin relatif
      '/signin', // boucle
      '/signup',
      '/splash',
      '/onboarding',
    ];

    for (final demandee in refusees) {
      test('${demandee ?? "null"} → /', () {
        expect(publicExitFor(demandee), '/');
      });
    }
  });

  test('une destination déjà publique est rendue telle quelle', () {
    // Ce cas arrive par l'écran de démarrage, qui transporte lui aussi un
    // `from`. Y renvoyer est correct : le client l'avait demandée.
    expect(publicExitFor('/restaurant/abc'), '/restaurant/abc');
    expect(publicExitFor('/cart'), '/cart');
  });

  test("l'accueil lui-même est un point fixe", () {
    expect(publicExitFor('/'), '/');
  });

  test('une destination trop longue est refusée', () {
    expect(publicExitFor('/cart/${'a' * 600}'), '/');
  });
}
