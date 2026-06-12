import 'package:dio/dio.dart';

/// Injecte le token Firebase dans chaque requête. Sur 401, force un refresh
/// du token UNE seule fois puis rejoue la requête. Découplé de Firebase :
/// reçoit deux callbacks. Doit être le premier interceptor.
class AuthInterceptor extends Interceptor {
  final Dio dio;
  final Future<String?> Function() tokenProvider;
  final Future<String?> Function() forceRefreshToken;

  AuthInterceptor(
    this.dio, {
    required this.tokenProvider,
    required this.forceRefreshToken,
  });

  static const _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenProvider();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    if (!is401 || alreadyRetried) {
      return handler.next(err);
    }

    final fresh = await forceRefreshToken();
    if (fresh == null) {
      return handler.next(err);
    }

    final options = err.requestOptions;
    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $fresh';
    try {
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
