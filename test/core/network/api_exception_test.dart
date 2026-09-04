import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';

void main() {
  group('ApiException', () {
    test('toString renvoie le message', () {
      const e = ApiException('Échec', statusCode: 500, kind: ApiErrorKind.server);
      expect(e.toString(), 'Échec');
      expect(e.statusCode, 500);
      expect(e.kind, ApiErrorKind.server);
    });

    test('kind par défaut = unknown', () {
      const e = ApiException('x');
      expect(e.kind, ApiErrorKind.unknown);
      expect(e.statusCode, isNull);
    });
  });
}
