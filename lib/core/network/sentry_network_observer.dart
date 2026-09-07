import 'package:sentry_flutter/sentry_flutter.dart';
import 'api_exception.dart';
import 'network_observer.dart';

/// Observateur réseau qui alimente les breadcrumbs Sentry pour le diagnostic
/// sans exposer de données personnelles ou de jetons sensibles.
class SentryNetworkObserver implements NetworkObserver {
  const SentryNetworkObserver();

  @override
  void onRequest(RequestSnapshot r) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb.http(
          url: Uri.parse(r.path),
          method: r.method,
          statusCode: r.statusCode,
          level: SentryLevel.info,
        ),
      );
    } catch (_) {
      // Évite tout crash si l'URL est malformée ou Sentry non initialisé
    }
  }

  @override
  void onError(ApiException e, RequestSnapshot r) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb.http(
          url: Uri.parse(r.path),
          method: r.method,
          statusCode: r.statusCode,
          level: SentryLevel.error,
          reason: '${e.kind.name}: ${e.message}',
        ),
      );
    } catch (_) {
      // Ignorer
    }
  }
}
