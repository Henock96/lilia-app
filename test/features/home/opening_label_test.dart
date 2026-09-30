import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/domain/opening_label.dart';
import 'package:lilia_app/models/restaurant.dart';

/// Libellé ouvert / fermé / réouverture (F3-03, UI Refresh).
void main() {
  final now = DateTime.utc(2026, 9, 28, 10); // lundi 11h00 à Brazzaville

  String label(
    bool? isOpen, {
    DateTime? paused,
    DateTime? next,
    bool served = true,
  }) => openingLabel(
    isOpen,
    paused,
    nextOpeningAt: next,
    nextOpeningServed: served,
    now: now,
  );

  test('ouvert', () => expect(label(true), 'Ouvert'));

  test('TEST CRITIQUE — isOpen null : jamais « Ouvert »', () {
    expect(label(null), 'Horaires indisponibles');
    // Même avec une heure servie : on ne sait pas s'il est fermé.
    expect(label(null, next: DateTime.utc(2026, 9, 28, 12)), isNot('Ouvert'));
  });

  test('TEST CRITIQUE — fermé, nextOpeningAt null : « Fermé » sans heure', () {
    expect(label(false), 'Fermé');
    // Une pause datée ne réintroduit pas d'heure : le serveur a dit « aucune
    // réouverture connue » (fermé à la main, rien sous 8 jours…).
    expect(label(false, paused: DateTime.utc(2026, 9, 28, 13)), 'Fermé');
  });

  test('réouverture aujourd’hui', () {
    expect(
      label(false, next: DateTime.utc(2026, 9, 28, 13, 30)),
      'Fermé — ouvre à 14h30',
    );
  });

  test('réouverture demain', () {
    expect(
      label(false, next: DateTime.utc(2026, 9, 29, 9)),
      'Fermé — demain à 10h00',
    );
  });

  test('réouverture plus tard : la date', () {
    expect(
      label(false, next: DateTime.utc(2026, 10, 2, 9)),
      'Fermé — le 02/10 à 10h00',
    );
  });

  test('« demain » au sens de Brazzaville, pas du téléphone', () {
    // 23h30 UTC = 00h30 le 29 à Brazzaville : « aujourd’hui ».
    expect(
      openingLabel(
        false,
        null,
        nextOpeningAt: DateTime.utc(2026, 9, 29, 8),
        nextOpeningServed: true,
        now: DateTime.utc(2026, 9, 28, 23, 30),
      ),
      'Fermé — ouvre à 09h00',
    );
  });

  test('pause au-delà de la fermeture : l’heure du serveur fait foi', () {
    // Pause jusqu'à 23h00, mais le vendeur ferme à 22h00 : le serveur
    // annonce demain 10h00, pas 23h00.
    expect(
      label(
        false,
        paused: DateTime.utc(2026, 9, 28, 22),
        next: DateTime.utc(2026, 9, 29, 9),
      ),
      'Fermé — demain à 10h00',
    );
  });

  test('instant échu (cache en retard) : « Fermé » sans heure passée', () {
    expect(label(false, next: DateTime.utc(2026, 9, 28, 9)), 'Fermé');
  });

  group('serveur antérieur (nextOpeningAt non servi)', () {
    test('pause du jour', () {
      expect(
        label(false, paused: DateTime.utc(2026, 9, 28, 13, 30), served: false),
        'Fermé — ouvre à 14h30',
      );
    });

    test('pause échue : fermé', () {
      expect(
        label(false, paused: DateTime.utc(2026, 9, 28, 9), served: false),
        'Fermé',
      );
    });

    test('sans pause : fermé', () {
      expect(label(false, served: false), 'Fermé');
    });
  });

  group('lecture de la réponse', () {
    Map<String, dynamic> base([Map<String, dynamic> extra = const {}]) => {
      'id': 'r1',
      'nom': 'Chez Lili',
      'adresse': 'Poto-Poto',
      ...extra,
    };

    test('isOpen absent : inconnu, et non plus « ouvert » (I5)', () {
      final r = RestaurantSummary.fromJson(base());
      expect(r.isOpen, isNull);
      expect(
        openingLabel(
          r.isOpen,
          r.pausedUntil,
          nextOpeningAt: r.nextOpeningAt,
          nextOpeningServed: r.nextOpeningServed,
        ),
        'Horaires indisponibles',
      );
    });

    test('nextOpeningAt servi, même null', () {
      final withDate = RestaurantSummary.fromJson(
        base({'isOpen': false, 'nextOpeningAt': '2026-09-29T09:00:00.000Z'}),
      );
      expect(withDate.nextOpeningAt, DateTime.utc(2026, 9, 29, 9));
      expect(withDate.nextOpeningServed, isTrue);

      final explicitNull = RestaurantSummary.fromJson(
        base({'isOpen': false, 'nextOpeningAt': null}),
      );
      expect(explicitNull.nextOpeningAt, isNull);
      expect(explicitNull.nextOpeningServed, isTrue);

      final legacy = RestaurantSummary.fromJson(base({'isOpen': false}));
      expect(legacy.nextOpeningServed, isFalse);
    });

    test('détail vendeur : mêmes champs', () {
      final r = Restaurant.fromJson({
        ...base({'isOpen': false, 'nextOpeningAt': '2026-09-29T09:00:00.000Z'}),
        'products': <dynamic>[],
      });
      expect(r.nextOpeningAt, DateTime.utc(2026, 9, 29, 9));
      expect(r.nextOpeningServed, isTrue);
    });
  });
}
