import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/utils/availability_window.dart';

/// **Le jumeau Dart de `availability-window-contract.spec.ts`.**
///
/// Les deux fichiers jouent le **même tableau de cas** sur deux
/// implémentations : celle du serveur (TypeScript) et le repli local (Dart).
/// Toute ligne ajoutée d'un côté doit l'être de l'autre — c'est le prix à payer
/// pour comparer deux langages, et c'est bien moins cher que de laisser les
/// deux règles diverger en silence.
///
/// L'implémentation précédente échouait sur **toute la section « nuit »** :
///
/// ```dart
/// return current.compareTo(availableFrom!) >= 0 &&
///        current.compareTo(availableUntil!) <= 0;   // ✗
/// ```
///
/// Pour « 22:00 → 02:00 » à 23:00 : `"23:00" <= "02:00"` ne tient pas. Un bar
/// de nuit n'était donc **jamais** commandable, et rien ne pouvait le révéler
/// sans ouvrir l'application à 23 h.
void main() {
  /// Une heure locale de Brazzaville (UTC+1), rendue en `DateTime` UTC.
  DateTime at(String hhmm) {
    final parts = hhmm.split(':').map(int.parse).toList();
    return DateTime.utc(2026, 9, 6, parts[0] - 1, parts[1]);
  }

  group('AvailabilityWindow.contains — contrat partagé avec le backend', () {
    // ─── Fenêtre de jour 10:00 → 18:00 ─────────────────────────────────────
    const jour = ('10:00', '18:00');
    for (final cas in <(String, bool)>[
      ('14:00', true), // au milieu
      ('10:00', true), // exactement à l'ouverture
      ('18:00', true), // exactement à la fermeture
      ('09:59', false), // une minute avant
      ('18:01', false), // une minute après
      ('03:00', false), // en pleine nuit
    ]) {
      test('jour 10:00→18:00 à ${cas.$1} → ${cas.$2}', () {
        expect(
          AvailabilityWindow.contains(
            from: jour.$1,
            until: jour.$2,
            now: at(cas.$1),
          ),
          cas.$2,
        );
      });
    }

    // ─── Fenêtre à cheval sur minuit 22:00 → 02:00 ─────────────────────────
    // Toute cette section rendait `false` avec l'ancienne implémentation.
    const nuit = ('22:00', '02:00');
    for (final cas in <(String, bool)>[
      ('22:30', true), // juste après l'ouverture
      ('22:00', true), // exactement à l'ouverture
      ('01:00', true), // après minuit
      ('02:00', true), // exactement à la fermeture
      ('02:01', false), // une minute après
      ('21:59', false), // une minute avant
      ('15:00', false), // en plein après-midi
    ]) {
      test('nuit 22:00→02:00 à ${cas.$1} → ${cas.$2}', () {
        expect(
          AvailabilityWindow.contains(
            from: nuit.$1,
            until: nuit.$2,
            now: at(cas.$1),
          ),
          cas.$2,
        );
      });
    }

    test('aucun créneau → toujours disponible', () {
      expect(AvailabilityWindow.contains(now: at('03:00')), isTrue);
    });

    test('ouverture seule', () {
      expect(
        AvailabilityWindow.contains(from: '08:00', now: at('07:00')),
        isFalse,
      );
      expect(
        AvailabilityWindow.contains(from: '08:00', now: at('09:00')),
        isTrue,
      );
    });

    test('fermeture seule', () {
      expect(
        AvailabilityWindow.contains(until: '20:00', now: at('19:00')),
        isTrue,
      );
      expect(
        AvailabilityWindow.contains(until: '20:00', now: at('21:00')),
        isFalse,
      );
    });
  });

  group('Le fuseau est celui de Brazzaville, pas celui de l’appareil', () {
    test('23:30 UTC = 00:30 à Brazzaville → dans la fenêtre 22:00 → 02:00', () {
      // L'ancienne version lisait `DateTime.now()` sans conversion : un
      // téléphone réglé sur un autre fuseau obtenait un verdict différent de
      // celui du serveur, qui décide au checkout.
      final minuitTrenteLocal = DateTime.utc(2026, 9, 6, 23, 30);
      expect(
        AvailabilityWindow.contains(
          from: '22:00',
          until: '02:00',
          now: minuitTrenteLocal,
        ),
        isTrue,
      );
    });

    test('localHHmm décale bien d’une heure', () {
      expect(
        AvailabilityWindow.localHHmm(DateTime.utc(2026, 9, 6, 9, 5)),
        '10:05',
      );
      // Passage de minuit : 23:30 UTC → 00:30 local.
      expect(
        AvailabilityWindow.localHHmm(DateTime.utc(2026, 9, 6, 23, 30)),
        '00:30',
      );
    });
  });
}
