import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/domain/opening_label.dart';
import 'package:lilia_app/models/restaurant.dart';

/// Badge ouvert / fermé (F3-03).
void main() {
  final now = DateTime.utc(2026, 9, 28, 10); // 11h00 à Brazzaville

  test('ouvert', () => expect(openingLabel(true, null, now: now), 'Ouvert'));

  test('fermé sans pause', () {
    expect(openingLabel(false, null, now: now), 'Fermé');
  });

  test('en pause aujourd’hui : l’heure de réouverture', () {
    expect(
      openingLabel(false, DateTime.utc(2026, 9, 28, 13, 30), now: now),
      'Rouvre à 14h30',
    );
  });

  test('en pause jusqu’à un autre jour : la date', () {
    expect(
      openingLabel(false, DateTime.utc(2026, 9, 30, 7), now: now),
      'Rouvre le 30/09 à 08h00',
    );
  });

  test('pause échue (colonne pas encore rafraîchie) : fermé', () {
    expect(
      openingLabel(false, DateTime.utc(2026, 9, 28, 9), now: now),
      'Fermé',
    );
  });

  test('pausedUntil lu depuis la réponse, absent d’un serveur antérieur', () {
    final paused = RestaurantSummary.fromJson({
      'id': 'r1',
      'nom': 'Chez Lili',
      'adresse': 'Poto-Poto',
      'isOpen': false,
      'pausedUntil': '2026-09-28T13:30:00.000Z',
    });
    expect(paused.pausedUntil, DateTime.utc(2026, 9, 28, 13, 30));
    final legacy = RestaurantSummary.fromJson({
      'id': 'r1',
      'nom': 'Chez Lili',
      'adresse': 'Poto-Poto',
    });
    expect(legacy.pausedUntil, isNull);
  });
}
