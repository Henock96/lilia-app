/// Nature de l'erreur réseau, pour adapter l'UI sans parser le message.
enum ApiErrorKind { network, timeout, unauthorized, server, client, unknown }

/// Exception unique remontée par l'ApiClient. [message] est en français,
/// prêt à être affiché tel quel par l'UI (`error.toString()`).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  /// Code métier posé par le serveur (`error.code`), ex. `ACCOUNT_NOT_SYNCED`.
  /// Se lire sur lui plutôt que sur le texte, qui peut changer.
  final String? code;

  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.unknown,
    this.code,
  });

  @override
  String toString() => message;
}
