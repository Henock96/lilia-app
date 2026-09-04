import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/location_precision.dart';

void main() {
  group('LocationPrecision', () {
    test('parse les trois valeurs du backend', () {
      expect(LocationPrecision.fromWire('EXACT'), LocationPrecision.exact);
      expect(
        LocationPrecision.fromWire('APPROXIMATE'),
        LocationPrecision.approximate,
      );
      expect(LocationPrecision.fromWire('UNKNOWN'), LocationPrecision.unknown);
    });

    // Le repli le plus important du fichier : une valeur que l'app ne connaît
    // pas — backend plus ancien, ou plus récent — doit faire *taire* la carte,
    // jamais la faire mentir.
    test('retombe sur unknown pour null ou une valeur inconnue', () {
      expect(LocationPrecision.fromWire(null), LocationPrecision.unknown);
      expect(LocationPrecision.fromWire('ROOFTOP'), LocationPrecision.unknown);
      expect(LocationPrecision.fromWire(''), LocationPrecision.unknown);
    });

    test('hasPosition n’autorise le marqueur que si un point existe', () {
      expect(LocationPrecision.exact.hasPosition, isTrue);
      expect(LocationPrecision.approximate.hasPosition, isTrue);
      expect(LocationPrecision.unknown.hasPosition, isFalse);
    });

    test('seul l’approximatif appelle une réserve à l’écran', () {
      expect(LocationPrecision.approximate.needsWarning, isTrue);
      expect(LocationPrecision.exact.needsWarning, isFalse);
      expect(LocationPrecision.unknown.needsWarning, isFalse);
    });

    test('aller-retour avec le backend', () {
      for (final value in LocationPrecision.values) {
        expect(LocationPrecision.fromWire(value.wireValue), value);
      }
    });
  });

  group('Adresse', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
      'id': 'adr-1',
      'rue': 'Rue Bayonne',
      'ville': 'Brazzaville',
      'country': 'Congo',
      'userId': 'u1',
      ...extra,
    };

    test('lit la position et sa précision', () {
      final adresse = Adresse.fromJson(
        json({
          'latitude': -4.274029,
          'longitude': 15.267756,
          'locationPrecision': 'EXACT',
          'landmark': 'Portail bleu',
          'label': 'Maison',
        }),
      );

      expect(adresse.latitude, -4.274029);
      expect(adresse.longitude, 15.267756);
      expect(adresse.locationPrecision, LocationPrecision.exact);
      expect(adresse.landmark, 'Portail bleu');
      expect(adresse.label, 'Maison');
      expect(adresse.hasPosition, isTrue);
      expect(adresse.needsPosition, isFalse);
    });

    // Compatibilité descendante : une adresse créée avant l'existence de ces
    // champs doit se parser sans exception et se signaler comme à compléter.
    test('parse une adresse historique sans position', () {
      final adresse = Adresse.fromJson(json({}));

      expect(adresse.latitude, isNull);
      expect(adresse.locationPrecision, LocationPrecision.unknown);
      expect(adresse.needsPosition, isTrue);
    });

    test('accepte des entiers là où des décimaux sont attendus', () {
      // `num` côté JSON : un backend qui sérialise -4.0 en -4 ne doit pas
      // faire planter le parsing.
      final adresse = Adresse.fromJson(
        json({'latitude': -4, 'longitude': 15, 'locationPrecision': 'EXACT'}),
      );
      expect(adresse.latitude, -4.0);
      expect(adresse.longitude, 15.0);
    });
  });
}
