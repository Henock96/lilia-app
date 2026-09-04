/// Nature de l'erreur réseau, pour adapter l'UI sans parser le message.
enum ApiErrorKind { network, timeout, unauthorized, server, client, unknown }

/// Exception unique remontée par l'ApiClient. [message] est en français,
/// prêt à être affiché tel quel par l'UI (`error.toString()`).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.unknown,
  });

  @override
  String toString() => message;
}
