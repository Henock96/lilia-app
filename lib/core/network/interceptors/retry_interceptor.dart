import 'dart:math';
import 'package:dio/dio.dart';

/// Rejoue les requêtes échouées sur 5xx / timeout / erreur réseau, avec
/// backoff exponentiel + jitter. Ne rejoue JAMAIS les 4xx. Les POST ne sont
/// rejoués que s'ils portent un header `Idempotency-Key` (checkout).
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Random _rng = Random();

  RetryInterceptor(
    this.dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 400),
  });

  static const _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;

    if (!_shouldRetry(err) || attempt >= maxRetries) {
      return handler.next(err);
    }

    final delay = _backoff(attempt);
    await Future<void>.delayed(delay);

    final options = err.requestOptions;
    options.extra[_attemptKey] = attempt + 1;
    try {
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Duration _backoff(int attempt) {
    final base = baseDelay.inMilliseconds * pow(2, attempt).toInt();
    final jitter = (base * 0.2 * (_rng.nextDouble() * 2 - 1)).toInt();
    return Duration(milliseconds: max(0, base + jitter));
  }

  bool _shouldRetry(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    final isIdempotent = method == 'GET' ||
        method == 'PUT' ||
        method == 'PATCH' ||
        method == 'DELETE';
    final hasIdempotencyKey =
        err.requestOptions.headers.containsKey('Idempotency-Key');
    if (!isIdempotent && !hasIdempotencyKey) return false;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status >= 500;
      default:
        return false;
    }
  }
}
