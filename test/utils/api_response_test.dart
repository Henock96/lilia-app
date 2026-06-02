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
}
