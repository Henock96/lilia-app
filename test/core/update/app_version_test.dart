import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/update/app_version.dart';

void main() {
  group('AppVersion', () {
    test('parses standard semver string', () {
      final v = AppVersion.parse('1.2.7');
      expect(v.major, equals(1));
      expect(v.minor, equals(2));
      expect(v.patch, equals(7));
      expect(v.buildNumber, isNull);
      expect(v.toString(), equals('1.2.7'));
    });

    test('parses semver with build number', () {
      final v = AppVersion.parse('1.2.7+32');
      expect(v.major, equals(1));
      expect(v.minor, equals(2));
      expect(v.patch, equals(7));
      expect(v.buildNumber, equals(32));
      expect(v.toString(), equals('1.2.7+32'));
    });

    test('parses string with leading v or whitespace', () {
      final v = AppVersion.parse('  v2.0.1+45 ');
      expect(v.major, equals(2));
      expect(v.minor, equals(0));
      expect(v.patch, equals(1));
      expect(v.buildNumber, equals(45));
    });

    test('tryParse returns null on invalid strings', () {
      expect(AppVersion.tryParse(null), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('invalid'), isNull);
      expect(AppVersion.tryParse('1.2'), isNull);
      expect(AppVersion.tryParse('1.2.a'), isNull);
    });

    test('compares versions correctly by major, minor, patch and build', () {
      final v1 = AppVersion.parse('1.2.0');
      final v2 = AppVersion.parse('1.2.1');
      final v3 = AppVersion.parse('1.3.0');
      final v4 = AppVersion.parse('2.0.0');

      expect(v1 < v2, isTrue);
      expect(v2 < v3, isTrue);
      expect(v3 < v4, isTrue);
      expect(v4 > v1, isTrue);
      expect(v1 <= v1, isTrue);
      expect(v1 >= v1, isTrue);
      expect(v1 == AppVersion.parse('1.2.0'), isTrue);

      final vBuild1 = AppVersion.parse('1.2.7+10');
      final vBuild2 = AppVersion.parse('1.2.7+20');
      expect(vBuild1 < vBuild2, isTrue);
      expect(vBuild2 > vBuild1, isTrue);
    });
  });
}
