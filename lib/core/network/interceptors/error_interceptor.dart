import 'package:dio/dio.dart';
import '../api_exception.dart';

/// Convertit toute DioException en [ApiException] avec un message FR.
/// Doit être le dernier interceptor d'erreur (après retry).
class ErrorInterceptor extends Interceptor {
  static const _fallback = 'Une erreur est survenue. Réessayez.';
  static const _network = 'Connexion impossible. Vérifiez votre réseau.';
  static const _timeout = 'Le serveur met trop de temps à répondre.';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      err.copyWith(error: _toApiException(err)),
    );
  }

  ApiException _toApiException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(_timeout, kind: ApiErrorKind.timeout);
      case DioExceptionType.connectionError:
        return const ApiException(_network, kind: ApiErrorKind.network);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        if (err.response == null) {
          return const ApiException(_network, kind: ApiErrorKind.network);
        }
        break;
      case DioExceptionType.badResponse:
        break;
    }
    final status = err.response?.statusCode;
    final message = _extractMessage(err.response?.data) ?? _fallback;
    return ApiException(message, statusCode: status, kind: _kindFor(status));
  }

  ApiErrorKind _kindFor(int? status) {
    if (status == null) return ApiErrorKind.unknown;
    if (status == 401) return ApiErrorKind.unauthorized;
    if (status >= 500) return ApiErrorKind.server;
    if (status >= 400) return ApiErrorKind.client;
    return ApiErrorKind.unknown;
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is List) return m.join('. ');
      return m.toString();
    }
    return null;
  }
}
