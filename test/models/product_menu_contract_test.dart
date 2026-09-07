import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/utils/currency.dart';

/// Le contrat de menu, côté modèle : prix, disponibilité, format des montants.
///
/// Chaque groupe correspond à une divergence mesurée entre le site et
/// l'application le 06/09/2026.
void main() {
  Product produit({
    List<double> prix = const [],
    double prixOriginal = 9999,
    int? stockRestant,
    bool isAvailable = true,
    bool? availableNow,
    String? from,
    String? until,
  }) {
    return Product(
      id: 'p1',
      name: 'Poulet braisé',
      description: '',
      prixOriginal: prixOriginal,
      restaurantId: 'r1',
      variants: [
        for (var i = 0; i < prix.length; i++)
          ProductVariant(id: 'v$i', label: 'Format $i', prix: prix[i]),
      ],
      stockRestant: stockRestant,
      isAvailable: isAvailable,
      availableNow: availableNow,
      availableFrom: from,
      availableUntil: until,
    );
  }

  group('startingPrice — le prix d’appel', () {
    test('prend le moins cher, quel que soit l’ordre reçu', () {
      // Le point capital : l'ordre des variantes n'était PAS garanti (18
      // `include` sans `orderBy` côté backend). `variants.first` — ce que
      // rendait l'ancien `displayPrice` — changeait donc tout seul après une
      // édition du produit.
      expect(produit(prix: [3500, 2500, 4500]).startingPrice, 2500);
      expect(produit(prix: [2500, 3500, 4500]).startingPrice, 2500);
      expect(produit(prix: [4500, 3500, 2500]).startingPrice, 2500);
    });

    test('aucune variante → le prix du produit', () {
      expect(produit(prixOriginal: 1800).startingPrice, 1800);
    });

    test('ignore les variantes à 0 plutôt que d’afficher « gratuit »', () {
      expect(produit(prix: [0, 2500]).startingPrice, 2500);
    });
  });

  group('priceLabel — même règle que le site', () {
    test('plusieurs prix distincts → « À partir de »', () {
      expect(produit(prix: [2500, 3500]).priceLabel, startsWith('À partir de'));
    });

    test('un seul format → son prix, sans « À partir de »', () {
      expect(produit(prix: [2500]).priceLabel, isNot(contains('À partir de')));
    });

    test('plusieurs formats au MÊME prix → pas de fourchette à annoncer', () {
      expect(produit(prix: [2500, 2500]).priceLabel, isNot(contains('À partir de')));
    });
  });

  group('formatPrice — plus jamais « 2500.0 FCFA »', () {
    test('pas de décimale : le franc CFA n’a pas de sous-unité', () {
      // Cinq écrans interpolaient un `double` directement — dans le panier et
      // les brouillons, c'est-à-dire là où le client vérifie ce qu'il paie.
      expect(formatPrice(2500.0), isNot(contains('.')));
      expect(formatPrice(2500.0), isNot(contains(',')));
    });

    test('séparateur de milliers : espace fine insécable, comme le site', () {
      // U+202F, exactement ce que produit `Intl.NumberFormat('fr-FR')` côté
      // web. L'ancien code annonçait « espace fine insécable » et écrivait une
      // espace ordinaire.
      expect(formatPrice(150000), '150 000 FCFA');
    });

    test('la devise s’écrit FCFA — alignée sur le site et sur le backend', () {
      // L'application écrivait « XAF », le site « FCFA », les SMS du backend
      // « FCFA ». Deux surfaces vues par le même acheteur se contredisaient.
      expect(formatPrice(2500), endsWith('FCFA'));
    });

    test('montants négatifs et zéro', () {
      expect(formatPrice(0), '0 FCFA');
      expect(formatPrice(-1500), '-1 500 FCFA');
    });
  });

  group('disponibilité — le serveur décide, le modèle relaie', () {
    test('availableNow du serveur l’emporte sur le calcul local', () {
      // Fenêtre déclarée absente mais serveur qui dit non : on dit non.
      expect(produit(availableNow: false).isWithinAvailabilityWindow, isFalse);
      // Et l'inverse : fenêtre qui semblerait fermée localement, serveur qui
      // dit oui. C'est lui qui accepte la commande, c'est lui qui a raison.
      expect(
        produit(availableNow: true, from: '06:00', until: '07:00')
            .isWithinAvailabilityWindow,
        isTrue,
      );
    });

    test('sans availableNow, repli sur la règle locale — la MÊME', () {
      expect(produit().isWithinAvailabilityWindow, isTrue);
    });

    test('stock null = illimité, jamais « épuisé »', () {
      // `?? 0` transformerait « illimité » en « épuisé » : le piège classique.
      expect(produit(stockRestant: null).isInStock, isTrue);
      expect(produit(stockRestant: 0).isInStock, isFalse);
    });

    test('isOrderable exige les trois conditions, fenêtre comprise', () {
      // La fenêtre horaire manquait : une viennoiserie « 06:00 → 11:00 »
      // restait proposée à 15 h, jusqu'au refus du serveur au checkout.
      expect(produit(stockRestant: 5).isOrderable, isTrue);
      expect(produit(stockRestant: 0).isOrderable, isFalse);
      expect(produit(stockRestant: 5, isAvailable: false).isOrderable, isFalse);
      expect(
        produit(stockRestant: 5, availableNow: false).isOrderable,
        isFalse,
      );
    });

    test('la cause est nommée — les trois n’appellent pas le même geste', () {
      // « Reviens demain », « cherche ailleurs », « reviens à 6 h ».
      expect(produit(stockRestant: 0).unavailability, ProductUnavailability.epuise);
      expect(
        produit(stockRestant: 5, isAvailable: false).unavailability,
        ProductUnavailability.retire,
      );
      expect(
        produit(stockRestant: 5, availableNow: false).unavailability,
        ProductUnavailability.horsCreneau,
      );
      expect(produit(stockRestant: 5).unavailability, isNull);
    });

    test('« retiré » prime sur « épuisé » — même ordre que le serveur', () {
      expect(
        produit(stockRestant: 0, isAvailable: false).unavailability,
        ProductUnavailability.retire,
      );
    });
  });

  group('parsing — les champs absents ne cassent rien', () {
    test('availableNow absent → null, donc repli local', () {
      final p = Product.fromJson({
        'id': 'p1',
        'nom': 'Poulet',
        'prixOriginal': 2500,
        'restaurantId': 'r1',
        'variants': <Map<String, dynamic>>[],
      });
      expect(p.availableNow, isNull);
      expect(p.isWithinAvailabilityWindow, isTrue);
      expect(p.isAvailable, isTrue);
    });

    test('availableNow présent est lu tel quel', () {
      final p = Product.fromJson({
        'id': 'p1',
        'nom': 'Croissant',
        'prixOriginal': 500,
        'restaurantId': 'r1',
        'variants': <Map<String, dynamic>>[],
        'availableNow': false,
        'availableFrom': '06:00',
        'availableUntil': '11:00',
      });
      expect(p.availableNow, isFalse);
      expect(p.isOrderable, isFalse);
      expect(p.unavailability, ProductUnavailability.horsCreneau);
    });
  });
}
