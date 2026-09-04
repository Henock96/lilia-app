import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/interceptors/retry_interceptor.dart';

/// Faux adapter qui compte les appels réels (chaque tentative = 1 fetch)
/// et renvoie un statut dépendant de l'index d'appel.
class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;
  final int Function(int call) statusForCall;
  _CountingAdapter(this.statusForCall);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statusForCall(calls++);
    return ResponseBody.fromString(
      jsonEncode({'message': 'x', 'data': 'ok'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_CountingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    RetryInterceptor(dio, maxRetries: 2, baseDelay: const Duration(milliseconds: 1)),
  );
  return dio;
}

void main() {
  test('retry sur 503 puis succès', () async {
    final adapter = _CountingAdapter((c) => c == 0 ? 503 : 200);
    final dio = _dioWith(adapter);
    final res = await dio.get<dynamic>('/flaky');
    expect(res.statusCode, 200);
    expect(adapter.calls, 2); // 1 échec + 1 retry réussi
  });

  test('pas de retry sur 400', () async {
    final adapter = _CountingAdapter((_) => 400);
    final dio = _dioWith(adapter);
    await expectLater(dio.get<dynamic>('/bad'), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });

  test('POST sans Idempotency-Key non retryé sur 503', () async {
    final adapter = _CountingAdapter((_) => 503);
    final dio = _dioWith(adapter);
    await expectLater(dio.post<dynamic>('/orders', data: {'x': 1}), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });

  test('POST avec Idempotency-Key retryé sur 503', () async {
    final adapter = _CountingAdapter((_) => 503);
    final dio = _dioWith(adapter);
    await expectLater(
      dio.post<dynamic>('/orders',
          data: {'x': 1},
          options: Options(headers: {'Idempotency-Key': 'abc'})),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 3); // initial + 2 retries (maxRetries=2)
  });
}
