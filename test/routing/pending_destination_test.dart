// R-05 — la destination demandée, et ce qu'on refuse d'en faire.
//
// Ces tests portent sur la seule fonction du routage qui reçoive une valeur
// d'origine externe : le paramètre `?from=`. Il arrive d'un lien profond, d'une
// charge utile de notification, ou d'une URL fabriquée. Tout ce qui en sort
// devient une destination de navigation — c'est donc là, et nulle part
// ailleurs, qu'on décide ce qui est acceptable.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/routing/pending_destination.dart';

void main() {
  group('sanitizeDestination — ce qui passe', () {
    test('un chemin interne simple', () {
      expect(sanitizeDestination('/commandes'), '/commandes');
    });

    test('un chemin avec paramètres de chemin', () {
      expect(
        sanitizeDestination('/commandes/abc-123'),
        '/commandes/abc-123',
      );
      expect(
        sanitizeDestination('/restaurant/123/product/456'),
        '/restaurant/123/product/456',
      );
    });

    test('la requête est conservée — un écran peut en dépendre', () {
      expect(
        sanitizeDestination('/restaurant/12?onglet=avis'),
        '/restaurant/12?onglet=avis',
      );
    });

    test('les espaces de bordure sont retirés', () {
      expect(sanitizeDestination('  /profile  '), '/profile');
    });

    test('un `from` imbriqué est retiré, le reste survit', () {
      expect(
        sanitizeDestination('/commandes?from=%2Fprofile&tri=date'),
        '/commandes?tri=date',
      );
    });

    test('les destinations citées par la Phase 2 sont toutes acceptées', () {
      for (final chemin in const [
        '/orders',
        '/profile',
        '/checkout',
        '/restaurant/123/product/456',
        '/commandes/abc',
        '/cart',
      ]) {
        expect(sanitizeDestination(chemin), chemin, reason: chemin);
      }
    });
  });

  group('sanitizeDestination — ce qui est refusé', () {
    test('null et vide', () {
      expect(sanitizeDestination(null), isNull);
      expect(sanitizeDestination(''), isNull);
      expect(sanitizeDestination('   '), isNull);
    });

    test('une URL absolue externe — redirection ouverte', () {
      expect(sanitizeDestination('https://exemple.com/vol'), isNull);
      expect(sanitizeDestination('http://exemple.com'), isNull);
    });

    test('une URL relative au protocole — la forme qu’on oublie', () {
      // `Uri.parse('//exemple.com/x')` lit `exemple.com` comme une AUTORITÉ.
      // Le test `startsWith('/')` seul laisserait passer : c'est la faille
      // classique de ce genre de garde.
      expect(sanitizeDestination('//exemple.com/vol'), isNull);
      expect(sanitizeDestination('///exemple.com'), isNull);
    });

    test('un schéma applicatif', () {
      expect(sanitizeDestination('liliafood://commandes'), isNull);
      expect(sanitizeDestination('javascript:alert(1)'), isNull);
    });

    test('un chemin relatif — go_router le résoudrait imprévisiblement', () {
      expect(sanitizeDestination('commandes/abc'), isNull);
      expect(sanitizeDestination('../profile'), isNull);
    });

    test('les emplacements qui boucleraient', () {
      // Y renvoyer après connexion : le redirect verrait un client connecté sur
      // un écran de connexion et le renverrait aussitôt, indéfiniment.
      expect(sanitizeDestination('/signin'), isNull);
      expect(sanitizeDestination('/signup'), isNull);
      expect(sanitizeDestination('/splash'), isNull);
      expect(sanitizeDestination('/onboarding'), isNull);
    });

    test('un emplacement de boucle même avec une requête', () {
      expect(sanitizeDestination('/signin?x=1'), isNull);
    });

    test('une destination démesurée n’a pas été produite par l’app', () {
      expect(sanitizeDestination('/${'a' * 600}'), isNull);
    });
  });

  group('construction des emplacements de transit', () {
    test('signInLocationFor encode la destination', () {
      expect(
        signInLocationFor('/commandes/abc'),
        '/signin?from=%2Fcommandes%2Fabc',
      );
    });

    test('signInLocationFor encode aussi une requête imbriquée', () {
      final emplacement = signInLocationFor('/restaurant/12?onglet=avis');
      // Ce qui compte n'est pas la forme exacte de l'encodage, mais qu'un
      // aller-retour rende la destination intacte.
      final from = Uri.parse(emplacement).queryParameters['from'];
      expect(from, '/restaurant/12?onglet=avis');
    });

    test('sans destination valable, on rend l’emplacement nu', () {
      expect(signInLocationFor(null), '/signin');
      expect(signInLocationFor('https://exemple.com'), '/signin');
      expect(signInLocationFor('/signin'), '/signin');
      expect(splashLocationFor(null), '/splash');
    });

    test('splashLocationFor porte la destination à travers le bootstrap', () {
      expect(
        splashLocationFor('/commandes/xyz'),
        '/splash?from=%2Fcommandes%2Fxyz',
      );
    });

    test('aucun emplacement construit n’est lui-même restaurable', () {
      // Garantit qu'un second tour ne peut pas empiler `from` sur `from`.
      expect(sanitizeDestination(signInLocationFor('/profile')), isNull);
      expect(sanitizeDestination(splashLocationFor('/profile')), isNull);
    });
  });
}
