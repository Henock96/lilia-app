import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/utils/api_response.dart';

void main() {
  group('ApiResponse.listOf', () {
    test('returns the list when payload is already a raw List', () {
      expect(
        ApiResponse.listOf([1, 2, 3]),
        equals([1, 2, 3]),
      );
    });

    test('unwraps { "data": [...] } envelope', () {
      expect(
        ApiResponse.listOf({
          'data': ['a', 'b'],
          'count': 2,
        }),
        equals(['a', 'b']),
      );
    });

    test('returns empty list for null, Map without data, or scalar', () {
      expect(ApiResponse.listOf(null), isEmpty);
      expect(ApiResponse.listOf({'foo': 'bar'}), isEmpty);
      expect(ApiResponse.listOf(42), isEmpty);
      expect(ApiResponse.listOf('hello'), isEmpty);
    });

    test('returns empty list when data field is not a List', () {
      expect(ApiResponse.listOf({'data': {'oops': true}}), isEmpty);
      expect(ApiResponse.listOf({'data': 'string'}), isEmpty);
    });
  });

  group('ApiResponse.mapOf', () {
    test('returns the map when payload is already a raw Map', () {
      expect(
        ApiResponse.mapOf({'id': 'abc', 'total': 100}),
        equals({'id': 'abc', 'total': 100}),
      );
    });

    test('unwraps { "data": {...} } envelope', () {
      expect(
        ApiResponse.mapOf({
          'data': {'id': 'xyz'},
          'message': 'ok',
        }),
        equals({'id': 'xyz'}),
      );
    });

    test('keeps outer map when data is not a Map (e.g. List)', () {
      // Outer map looks like a wrapper but data is a List — caller likely
      // wanted listOf; mapOf must still return *something* sensible.
      final result = ApiResponse.mapOf({
        'data': [1, 2, 3],
        'count': 3,
      });
      expect(result['data'], equals([1, 2, 3]));
      expect(result['count'], equals(3));
    });

    test('throws StateError when payload is not a Map', () {
      expect(() => ApiResponse.mapOf(null), throwsStateError);
      expect(() => ApiResponse.mapOf([1, 2, 3]), throwsStateError);
      expect(() => ApiResponse.mapOf('string'), throwsStateError);
      expect(() => ApiResponse.mapOf(42), throwsStateError);
    });
  });

  // Régression : depuis api-contract-v2 (interceptor global backend), les
  // endpoints dont le payload portait des clés hors { data, message, meta }
  // (ex: `count`) sont DOUBLE-enveloppés : { data: { message, data: [...], count } }.
  group('Backend api-contract-v2 wrapped shapes', () {
    test('GET /menus/active double-wrappé → listOf∘mapOf rend la liste', () {
      // Shape réel observé en prod (curl) :
      final decoded = {
        'data': {
          'message': 'Menus actifs récupérés avec succès',
          'data': [
            {'id': 'm1'},
            {'id': 'm2'},
          ],
          'count': 2,
        },
      };

      // Reproduit le bug : l'ancien parsing `decoded['data'] as List` casse
      // car decoded['data'] est un Map, pas une List.
      expect(decoded['data'], isA<Map<String, dynamic>>());

      // Le correctif : déballe l'enveloppe externe puis lit `data`.
      final menus = ApiResponse.listOf(ApiResponse.mapOf(decoded));
      expect(menus, hasLength(2));
      expect((menus.first as Map)['id'], equals('m1'));
    });

    test('menus shape simple { data: [...] } reste géré', () {
      final decoded = {
        'data': [
          {'id': 'm1'},
        ],
      };
      expect(ApiResponse.listOf(ApiResponse.mapOf(decoded)), hasLength(1));
    });

    test('GET /users/me wrappé { data: { user } } → user via mapOf', () {
      // Backend : `return { user }` → interceptor → { data: { user } }.
      final decoded = {
        'data': {
          'user': {'id': 'u1', 'firebaseUid': 'fuid', 'email': 'a@b.cg'},
        },
      };

      // Reproduit le bug : l'ancien `decoded['user']` est null.
      expect(decoded['user'], isNull);

      // Le correctif : déballe puis lit `user`.
      final unwrapped = ApiResponse.mapOf(decoded);
      final userMap = (unwrapped['user'] ?? unwrapped) as Map<String, dynamic>;
      expect(userMap['firebaseUid'], equals('fuid'));
    });

    test('users/me legacy non-wrappé { user } reste géré', () {
      final decoded = {
        'user': {'id': 'u1', 'firebaseUid': 'fuid'},
      };
      final unwrapped = ApiResponse.mapOf(decoded);
      final userMap = (unwrapped['user'] ?? unwrapped) as Map<String, dynamic>;
      expect(userMap['firebaseUid'], equals('fuid'));
    });
  });
}
