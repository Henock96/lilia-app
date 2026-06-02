/// Helpers to read backend responses regardless of whether the payload is
/// returned raw or wrapped in a `{ "data": ... }` envelope.
///
/// The Lilia Food backend is being normalized in parallel work (J2 sprint).
/// In the meantime, the client must tolerate both shapes to avoid crashes
/// when a route returns a raw list/object while another wraps it.
class ApiResponse {
  /// Returns a List from either a raw List response or `{ data: [...] }`.
  /// Falls back to an empty list when the payload is neither shape.
  static List<dynamic> listOf(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      return decoded['data'] as List<dynamic>;
    }
    return <dynamic>[];
  }

  /// Returns a Map from either a raw Map response or `{ data: {...} }`.
  /// Throws when the payload is not a Map at all.
  static Map<String, dynamic> mapOf(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is Map<String, dynamic>) {
        return decoded['data'] as Map<String, dynamic>;
      }
      return decoded;
    }
    throw StateError('Expected Map response, got ${decoded.runtimeType}');
  }
}
