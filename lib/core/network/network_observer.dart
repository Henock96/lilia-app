import 'api_exception.dart';

/// Vue immuable d'une requête, passée à l'observateur. Pas de payload (PII).
class RequestSnapshot {
  final String method;
  final String path;
  final int? statusCode;
  final Duration? elapsed;

  const RequestSnapshot({
    required this.method,
    required this.path,
    this.statusCode,
    this.elapsed,
  });
}

/// Point d'extension pour l'observabilité (breadcrumbs Sentry, logs).
/// Volontairement minimal : l'implémentation Sentry viendra dans une issue
/// dédiée. L'ApiClient ne dépend que de cette interface.
abstract class NetworkObserver {
  void onRequest(RequestSnapshot r);
  void onError(ApiException e, RequestSnapshot r);
}

/// Implémentation par défaut : ne fait rien.
class NoopNetworkObserver implements NetworkObserver {
  const NoopNetworkObserver();
  @override
  void onRequest(RequestSnapshot r) {}
  @override
  void onError(ApiException e, RequestSnapshot r) {}
}
