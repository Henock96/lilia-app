// C-03 / C-08 / C-33 — audit du 09/10/2026 : miroir de `IsCongoMobilePhone`.
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/user/domain/profile_update.dart';
import 'package:lilia_app/utils/congo_phone.dart';

void main() {
  group('normalizeCongoPhone', () {
    test('retire espaces, points, tirets et parenthèses', () {
      expect(normalizeCongoPhone(' 06 123 45 67 '), '061234567');
      expect(normalizeCongoPhone('+242 (06) 123-45.67'), '+242061234567');
    });
  });

  group('isCongoMobilePhone — mêmes verdicts que le serveur', () {
    for (final ok in [
      '06 123 45 67',
      '061234567',
      '+242 06 123 45 67',
      '242061234567',
      '05 123 45 67',
      '04 123 45 67',
      '61234567',
    ]) {
      test('accepte « $ok »', () => expect(isCongoMobilePhone(ok), isTrue));
    }
    for (final ko in [
      '',
      '123456789',
      '07 123 45 67',
      '06 123 45 6',
      '06 123 45 678',
      '+33 6 12 34 56 78',
      '06a1234567',
    ]) {
      test('refuse « $ko »', () => expect(isCongoMobilePhone(ko), isFalse));
    }
  });

  group('profileUpdatePayload (C-08)', () {
    test('téléphone vide : non envoyé, le numéro existant est conservé', () {
      expect(
        profileUpdatePayload(nom: ' Jean ', phone: '  '),
        {'nom': 'Jean'},
      );
    });

    test('téléphone saisi avec espaces : envoyé normalisé', () {
      expect(
        profileUpdatePayload(nom: 'Jean', phone: '06 123 45 67'),
        {'nom': 'Jean', 'phone': '061234567'},
      );
    });
  });
}
