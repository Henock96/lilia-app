import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/network/interceptors/error_interceptor.dart';

/// Le code métier du serveur (`error.code`) traverse jusqu'à `ApiException`.
void main() {
  Future<ApiException> run(Map<String, dynamic> body, int status) async {
    final options = RequestOptions(path: '/x');
    late ApiException captured;
    final handler = _CapturingHandler(
      (e) => captured = e.error as ApiException,
    );
    ErrorInterceptor().onError(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: body,
        ),
      ),
      handler,
    );
    return captured;
  }

  test('lit error.code', () async {
    final e = await run({
      'success': false,
      'message': 'Compte non synchronisé.',
      'error': {'code': 'ACCOUNT_NOT_SYNCED'},
      'statusCode': 403,
    }, 403);
    expect(e.code, 'ACCOUNT_NOT_SYNCED');
    expect(e.statusCode, 403);
  });

  test('sans code : null', () async {
    final e = await run({'message': 'Accès refusé', 'error': null}, 403);
    expect(e.code, isNull);
  });
}

class _CapturingHandler extends ErrorInterceptorHandler {
  _CapturingHandler(this.onReject);
  final void Function(DioException) onReject;
  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) => onReject(error);
}
