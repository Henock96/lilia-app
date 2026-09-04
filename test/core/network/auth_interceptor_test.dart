import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/interceptors/auth_interceptor.dart';

/// Faux adapter : capture le dernier header Authorization et renvoie un statut
/// dépendant de l'index d'appel.
class _AuthAdapter implements HttpClientAdapter {
  int calls = 0;
  String? lastAuth;
  final int Function(int call) statusForCall;
  _AuthAdapter(this.statusForCall);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastAuth = options.headers['Authorization'] as String?;
    final status = statusForCall(calls++);
    return ResponseBody.fromString(
      jsonEncode({'data': 'ok', 'message': 'x'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('injecte le Bearer token', () async {
    final adapter = _AuthAdapter((_) => 200);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(
      dio,
      tokenProvider: () async => 'tok-123',
      forceRefreshToken: () async => 'tok-refreshed',
    ));
    await dio.get<dynamic>('/me');
    expect(adapter.lastAuth, 'Bearer tok-123');
  });

  test('401 => un seul force-refresh puis replay', () async {
    var refreshCount = 0;
    final adapter = _AuthAdapter((c) => c == 0 ? 401 : 200);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(
      dio,
      tokenProvider: () async => 'expired',
      forceRefreshToken: () async {
        refreshCount++;
        return 'fresh';
      },
    ));
    final res = await dio.get<dynamic>('/secure');
    expect(res.statusCode, 200);
    expect(refreshCount, 1);
    expect(adapter.calls, 2);
  });

  test('401 persistant => un seul refresh puis échec (pas de boucle)', () async {
    var refreshCount = 0;
    final adapter = _AuthAdapter((_) => 401);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(
      dio,
      tokenProvider: () async => 'expired',
      forceRefreshToken: () async {
        refreshCount++;
        return 'still-bad';
      },
    ));
    await expectLater(dio.get<dynamic>('/secure'), throwsA(isA<DioException>()));
    expect(refreshCount, 1);
    expect(adapter.calls, 2); // initial + 1 seul replay
  });
}
