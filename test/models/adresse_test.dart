import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/location_precision.dart';

/// Adresse client : ce qui est humain, ce qui est machine, et qui décide.
///
/// La règle de la plateforme tient en une phrase : `latitude + longitude`
/// **n'est pas** une adresse de livraison. Les deux coexistent, aucune ne
/// remplace l'autre, et c'est le serveur qui qualifie la fiabilité du point.
Map<String, dynamic> _json({
  Object? latitude,
  Object? longitude,
  Object? locationPrecision,
  Object? label,
  Object? landmark,
  Object? isDefault,
  Object? quartier,
}) => <String, dynamic>{
  'id': 'adr_1',
  'rue': 'Rue Bayonne',
  'ville': 'Brazzaville',
  'country': 'Congo',
  'userId': 'usr_1',
  'quartierId': quartier == null ? null : 'qtr_1',
  'quartier': quartier,
  'latitude': latitude,
  'longitude': longitude,
  'locationPrecision': locationPrecision,
  'label': label,
  'landmark': landmark,
  'isDefault': isDefault,
};

void main() {
  group('Adresse — position', () {
    test('une adresse située porte son point et sa précision', () {
      final a = Adresse.fromJson(
        _json(
          latitude: -4.2634,
          longitude: 15.2429,
          locationPrecision: 'EXACT',
          landmark: 'Portail bleu face à la pharmacie',
        ),
      );

      expect(a.hasPosition, isTrue);
      expect(a.needsPosition, isFalse);
      expect(a.locationPrecision, LocationPrecision.exact);
      expect(a.landmark, 'Portail bleu face à la pharmacie');
    });

    test('une adresse sans point reste valide et le signale', () {
      // Elle demeure livrable — le serveur retombe sur le centroïde du
      // quartier — mais l'interface doit le dire avant la commande.
      final a = Adresse.fromJson(_json());

      expect(a.hasPosition, isFalse);
      expect(a.needsPosition, isTrue);
      expect(a.locationPrecision, LocationPrecision.unknown);
      expect(a.rue, 'Rue Bayonne');
    });

    test('une coordonnée seule ne fait pas une position', () {
      final a = Adresse.fromJson(_json(latitude: -4.2634));
      expect(a.hasPosition, isFalse);
    });

    test('une précision inconnue du client ne devient jamais une position', () {
      // Un backend plus récent pourrait ajouter une valeur ; la retomber sur
      // « unknown » fait taire la carte au lieu de la faire mentir.
      final a = Adresse.fromJson(
        _json(locationPrecision: 'QUARTIER_CENTER'),
      );
      expect(a.locationPrecision, LocationPrecision.unknown);
    });
  });

  group('Adresse — libellé', () {
    test('le nom donné par le client prime sur la rue', () {
      final a = Adresse.fromJson(_json(label: 'Maison'));
      expect(a.displayLabel, 'Maison');
    });

    test('sans nom, la rue fait office de libellé', () {
      expect(Adresse.fromJson(_json()).displayLabel, 'Rue Bayonne');
    });

    test('un libellé vide ou blanc ne masque pas la rue', () {
      expect(Adresse.fromJson(_json(label: '')).displayLabel, 'Rue Bayonne');
      expect(Adresse.fromJson(_json(label: '   ')).displayLabel, 'Rue Bayonne');
    });
  });

  group('Adresse — adresse principale', () {
    test('isDefault vient du serveur', () {
      expect(Adresse.fromJson(_json(isDefault: true)).isDefault, isTrue);
    });

    test('une réponse sans isDefault ne désigne aucune principale', () {
      // Le badge se posait auparavant sur le premier élément d'une liste
      // triée par date décroissante : il désignait la **dernière adresse
      // créée** et changeait tout seul dès qu'on en ajoutait une.
      expect(Adresse.fromJson(_json()).isDefault, isFalse);
    });
  });
}
