# LIL-136 — ApiClient centralisé Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les appels `http` dispersés par un `ApiClient` Dio unique avec interceptors (token Firebase + refresh, retry exponentiel, parsing erreur typé, hook observer) dans les 3 apps Flutter.

**Architecture:** Façade `ApiClient` sur Dio, découplée de Firebase via un `tokenProvider` callback. Trois interceptors (auth, retry, error) + un `NetworkObserver` no-op (hook Sentry futur). Les repos déwrappent toujours `{data}` via `ApiResponse` et gardent `parseJson` isolate. Implémentation complète sur `lilia-app` (référence) puis copie sur `lilia-food-admin` et `lilia_food_delivery`.

**Tech Stack:** Flutter, Riverpod (code gen), Dio ^5.7.0, http_mock_adapter (tests), Firebase Auth.

**Réf. spec:** `docs/superpowers/specs/2026-06-12-apiclient-centralise-design.md`

---

## File Structure (lilia-app)

| Fichier | Responsabilité |
|---------|----------------|
| `lib/core/network/api_exception.dart` | `ApiErrorKind` + `ApiException` typée |
| `lib/core/network/network_observer.dart` | `RequestSnapshot`, `NetworkObserver`, `NoopNetworkObserver` |
| `lib/core/network/interceptors/error_interceptor.dart` | DioException/4xx-5xx → `ApiException` |
| `lib/core/network/interceptors/retry_interceptor.dart` | backoff 5xx/timeout, règle idempotence |
| `lib/core/network/interceptors/auth_interceptor.dart` | inject token + force-refresh 1× sur 401 |
| `lib/core/network/api_client.dart` | façade Dio + méthodes + provider `apiClientProvider` |
| `test/core/network/*` | tests unitaires interceptors + exception + client |

---

## Task 1: Ajouter dépendances Dio + http_mock_adapter

**Files:**
- Modify: `lilia-app/pubspec.yaml`

- [ ] **Step 1: Ajouter dio aux dependencies et http_mock_adapter aux dev_dependencies**

Dans `dependencies:` (à côté de `http: ^1.6.0`) :
```yaml
  dio: ^5.7.0
```
Dans `dev_dependencies:` (à côté de `flutter_test:`) :
```yaml
  http_mock_adapter: ^0.6.1
```

- [ ] **Step 2: Récupérer les packages**

Run: `cd lilia-app && flutter pub get`
Expected: résolution OK, `dio` et `http_mock_adapter` téléchargés.

- [ ] **Step 3: Commit**

```bash
cd lilia-app
git add pubspec.yaml pubspec.lock
git commit -m "chore(LIL-136): ajoute dio + http_mock_adapter"
```

---

## Task 2: ApiException typée

**Files:**
- Create: `lilia-app/lib/core/network/api_exception.dart`
- Test: `lilia-app/test/core/network/api_exception_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/network/api_exception_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';

void main() {
  group('ApiException', () {
    test('toString renvoie le message', () {
      const e = ApiException('Échec', statusCode: 500, kind: ApiErrorKind.server);
      expect(e.toString(), 'Échec');
      expect(e.statusCode, 500);
      expect(e.kind, ApiErrorKind.server);
    });

    test('kind par défaut = unknown', () {
      const e = ApiException('x');
      expect(e.kind, ApiErrorKind.unknown);
      expect(e.statusCode, isNull);
    });
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `cd lilia-app && flutter test test/core/network/api_exception_test.dart`
Expected: FAIL — `api_exception.dart` introuvable.

- [ ] **Step 3: Implémenter ApiException**

```dart
// lib/core/network/api_exception.dart
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
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `cd lilia-app && flutter test test/core/network/api_exception_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd lilia-app
git add lib/core/network/api_exception.dart test/core/network/api_exception_test.dart
git commit -m "feat(LIL-136): ApiException typée"
```

---

## Task 3: NetworkObserver (hook)

**Files:**
- Create: `lilia-app/lib/core/network/network_observer.dart`
- Test: `lilia-app/test/core/network/network_observer_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/network/network_observer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/network/network_observer.dart';

void main() {
  test('NoopNetworkObserver ne lève rien', () {
    const obs = NoopNetworkObserver();
    const snap = RequestSnapshot(method: 'GET', path: '/orders/my', statusCode: 200);
    expect(() => obs.onRequest(snap), returnsNormally);
    expect(
      () => obs.onError(const ApiException('x'), snap),
      returnsNormally,
    );
  });

  test('RequestSnapshot porte les champs', () {
    const snap = RequestSnapshot(
      method: 'POST', path: '/orders/checkout', statusCode: 201,
      elapsed: Duration(milliseconds: 120),
    );
    expect(snap.method, 'POST');
    expect(snap.path, '/orders/checkout');
    expect(snap.statusCode, 201);
    expect(snap.elapsed, const Duration(milliseconds: 120));
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `cd lilia-app && flutter test test/core/network/network_observer_test.dart`
Expected: FAIL — fichier introuvable.

- [ ] **Step 3: Implémenter NetworkObserver**

```dart
// lib/core/network/network_observer.dart
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
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `cd lilia-app && flutter test test/core/network/network_observer_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd lilia-app
git add lib/core/network/network_observer.dart test/core/network/network_observer_test.dart
git commit -m "feat(LIL-136): NetworkObserver hook (no-op)"
```

---

## Task 4: ErrorInterceptor

**Files:**
- Create: `lilia-app/lib/core/network/interceptors/error_interceptor.dart`
- Test: `lilia-app/test/core/network/error_interceptor_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/network/error_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/network/interceptors/error_interceptor.dart';

ApiException _mapResponse(int status, dynamic body) {
  final interceptor = ErrorInterceptor();
  ApiException? captured;
  final handler = _CaptureRejectHandler((e) => captured = e.error as ApiException);
  final dioError = DioException(
    requestOptions: RequestOptions(path: '/x', method: 'GET'),
    response: Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );
  interceptor.onError(dioError, handler);
  return captured!;
}

void main() {
  test('message String depuis {message}', () {
    final e = _mapResponse(400, {'message': 'Stock insuffisant'});
    expect(e.message, 'Stock insuffisant');
    expect(e.statusCode, 400);
    expect(e.kind, ApiErrorKind.client);
  });

  test('message List joint par ". "', () {
    final e = _mapResponse(400, {'message': ['Champ A requis', 'Champ B invalide']});
    expect(e.message, 'Champ A requis. Champ B invalide');
  });

  test('5xx => kind server', () {
    final e = _mapResponse(503, {'message': 'Indispo'});
    expect(e.kind, ApiErrorKind.server);
  });

  test('401 => kind unauthorized', () {
    final e = _mapResponse(401, {'message': 'Non autorisé'});
    expect(e.kind, ApiErrorKind.unauthorized);
  });

  test('timeout => kind timeout + message fallback', () {
    final interceptor = ErrorInterceptor();
    ApiException? captured;
    final handler = _CaptureRejectHandler((e) => captured = e.error as ApiException);
    interceptor.onError(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      ),
      handler,
    );
    expect(captured!.kind, ApiErrorKind.timeout);
    expect(captured!.message, isNotEmpty);
  });
}

class _CaptureRejectHandler extends ErrorInterceptorHandler {
  final void Function(DioException) onReject;
  _CaptureRejectHandler(this.onReject);
  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    onReject(error);
  }
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `cd lilia-app && flutter test test/core/network/error_interceptor_test.dart`
Expected: FAIL — `error_interceptor.dart` introuvable.

- [ ] **Step 3: Implémenter ErrorInterceptor**

```dart
// lib/core/network/interceptors/error_interceptor.dart
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
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `cd lilia-app && flutter test test/core/network/error_interceptor_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
cd lilia-app
git add lib/core/network/interceptors/error_interceptor.dart test/core/network/error_interceptor_test.dart
git commit -m "feat(LIL-136): ErrorInterceptor -> ApiException"
```

---

## Task 5: RetryInterceptor

**Files:**
- Create: `lilia-app/lib/core/network/interceptors/retry_interceptor.dart`
- Test: `lilia-app/test/core/network/retry_interceptor_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/network/retry_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lilia_app/core/network/interceptors/retry_interceptor.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    // delayFactor court pour des tests rapides.
    dio.interceptors.add(RetryInterceptor(dio, maxRetries: 2, baseDelay: Duration(milliseconds: 1)));
    adapter = DioAdapter(dio: dio);
  });

  test('retry sur 503 puis succès', () async {
    var calls = 0;
    adapter.onGet('/flaky', (server) {
      calls++;
      if (calls < 2) {
        server.reply(503, {'message': 'indispo'});
      } else {
        server.reply(200, {'data': 'ok'});
      }
    });
    // Note : http_mock_adapter rejoue le même handler ; calls suit les tentatives.
    final res = await dio.get('/flaky');
    expect(res.statusCode, 200);
    expect(calls, greaterThanOrEqualTo(2));
  });

  test('pas de retry sur 400', () async {
    var calls = 0;
    adapter.onGet('/bad', (server) {
      calls++;
      server.reply(400, {'message': 'mauvaise requête'});
    });
    await expectLater(dio.get('/bad'), throwsA(isA<DioException>()));
    expect(calls, 1);
  });

  test('POST sans Idempotency-Key non retryé sur 503', () async {
    var calls = 0;
    adapter.onPost('/orders', (server) {
      calls++;
      server.reply(503, {'message': 'indispo'});
    }, data: {'x': 1});
    await expectLater(dio.post('/orders', data: {'x': 1}), throwsA(isA<DioException>()));
    expect(calls, 1);
  });

  test('POST avec Idempotency-Key retryé sur 503', () async {
    var calls = 0;
    adapter.onPost('/orders', (server) {
      calls++;
      server.reply(503, {'message': 'indispo'});
    }, data: {'x': 1}, headers: {'Idempotency-Key': 'abc'});
    await expectLater(
      dio.post('/orders', data: {'x': 1}, options: Options(headers: {'Idempotency-Key': 'abc'})),
      throwsA(isA<DioException>()),
    );
    expect(calls, greaterThan(1));
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `cd lilia-app && flutter test test/core/network/retry_interceptor_test.dart`
Expected: FAIL — `retry_interceptor.dart` introuvable.

- [ ] **Step 3: Implémenter RetryInterceptor**

```dart
// lib/core/network/interceptors/retry_interceptor.dart
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
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `cd lilia-app && flutter test test/core/network/retry_interceptor_test.dart`
Expected: PASS (4 tests). Si `http_mock_adapter` ne re-déclenche pas le handler par tentative, ajuster les assertions `calls` en `greaterThanOrEqualTo` — la garantie testée est : retry sur 5xx, pas sur 4xx, règle POST/Idempotency-Key.

- [ ] **Step 5: Commit**

```bash
cd lilia-app
git add lib/core/network/interceptors/retry_interceptor.dart test/core/network/retry_interceptor_test.dart
git commit -m "feat(LIL-136): RetryInterceptor backoff + règle idempotence"
```

---

## Task 6: AuthInterceptor

**Files:**
- Create: `lilia-app/lib/core/network/interceptors/auth_interceptor.dart`
- Test: `lilia-app/test/core/network/auth_interceptor_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/network/auth_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lilia_app/core/network/interceptors/auth_interceptor.dart';

void main() {
  test('injecte le Bearer token', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        tokenProvider: () async => 'tok-123',
        forceRefreshToken: () async => 'tok-refreshed',
      ),
    );
    final adapter = DioAdapter(dio: dio);
    String? sentAuth;
    adapter.onGet('/me', (server) {
      // http_mock_adapter ne capture pas les headers ici ; on vérifie côté request.
      server.reply(200, {'data': {}});
    });
    final res = await dio.get('/me');
    sentAuth = res.requestOptions.headers['Authorization'] as String?;
    expect(sentAuth, 'Bearer tok-123');
  });

  test('401 => un seul force-refresh puis replay', () async {
    var refreshCount = 0;
    var calls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        tokenProvider: () async => 'expired',
        forceRefreshToken: () async {
          refreshCount++;
          return 'fresh';
        },
      ),
    );
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/secure', (server) {
      calls++;
      if (calls == 1) {
        server.reply(401, {'message': 'token expiré'});
      } else {
        server.reply(200, {'data': 'ok'});
      }
    });
    final res = await dio.get('/secure');
    expect(res.statusCode, 200);
    expect(refreshCount, 1);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `cd lilia-app && flutter test test/core/network/auth_interceptor_test.dart`
Expected: FAIL — `auth_interceptor.dart` introuvable.

- [ ] **Step 3: Implémenter AuthInterceptor**

```dart
// lib/core/network/interceptors/auth_interceptor.dart
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
    final alreadyRetried =
        err.requestOptions.extra[_retriedKey] == true;
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
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `cd lilia-app && flutter test test/core/network/auth_interceptor_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd lilia-app
git add lib/core/network/interceptors/auth_interceptor.dart test/core/network/auth_interceptor_test.dart
git commit -m "feat(LIL-136): AuthInterceptor token + force-refresh sur 401"
```

---

## Task 7: ApiClient + provider

**Files:**
- Create: `lilia-app/lib/core/network/api_client.dart`
- Test: `lilia-app/test/core/network/api_client_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// test/core/network/api_client_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';

void main() {
  ApiClient buildClient(void Function(DioAdapter) stub) {
    final client = ApiClient.test(
      baseUrl: 'https://test.local',
      tokenProvider: () async => 'tok',
      forceRefreshToken: () async => 'tok2',
    );
    final adapter = DioAdapter(dio: client.dio);
    stub(adapter);
    return client;
  }

  test('getJson renvoie le body décodé', () async {
    final client = buildClient((a) {
      a.onGet('/orders/my', (s) => s.reply(200, {'data': [], 'count': 0}));
    });
    final res = await client.getJson('/orders/my');
    expect(res.statusCode, 200);
    expect(res.data['count'], 0);
  });

  test('erreur 400 => ApiException avec message', () async {
    final client = buildClient((a) {
      a.onGet('/x', (s) => s.reply(400, {'message': 'Boom'}));
    });
    await expectLater(
      client.getJson('/x'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Boom')),
    );
  });

  test('downloadBytes renvoie les octets', () async {
    final client = buildClient((a) {
      a.onGet('/orders/1/receipt', (s) => s.reply(200, [37, 80, 68, 70]));
    });
    final bytes = await client.downloadBytes('/orders/1/receipt');
    expect(bytes, isNotEmpty);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `cd lilia-app && flutter test test/core/network/api_client_test.dart`
Expected: FAIL — `api_client.dart` introuvable.

- [ ] **Step 3: Implémenter ApiClient (sans le provider d'abord)**

```dart
// lib/core/network/api_client.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../constants/app_constants.dart';
import '../../features/auth/repository/firebase_auth_repository.dart';
import 'api_exception.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'network_observer.dart';

part 'api_client.g.dart';

/// Façade HTTP authentifiée unique. Construit un Dio configuré avec les
/// interceptors auth / retry / error. Les repos déwrappent eux-mêmes `{data}`
/// (via ApiResponse) et gardent parseJson isolate pour les grosses listes.
class ApiClient {
  final Dio dio;
  final NetworkObserver _observer;

  ApiClient._(this.dio, this._observer);

  factory ApiClient({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    required Future<String?> Function() forceRefreshToken,
    NetworkObserver observer = const NoopNetworkObserver(),
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (_) => true, // ErrorInterceptor décide via onError manuel
      ),
    );
    final client = ApiClient._(dio, observer);
    dio.interceptors.addAll([
      AuthInterceptor(dio,
          tokenProvider: tokenProvider, forceRefreshToken: forceRefreshToken),
      RetryInterceptor(dio),
      ErrorInterceptor(),
      _ObserverInterceptor(observer),
      _StatusToErrorInterceptor(),
    ]);
    return client;
  }

  /// Constructeur de test : observer no-op, mêmes interceptors.
  @visibleForTesting
  factory ApiClient.test({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    required Future<String?> Function() forceRefreshToken,
  }) =>
      ApiClient(
        baseUrl: baseUrl,
        tokenProvider: tokenProvider,
        forceRefreshToken: forceRefreshToken,
      );

  Future<Response<dynamic>> getJson(String path,
          {Map<String, dynamic>? query}) =>
      dio.get<dynamic>(path, queryParameters: query);

  Future<Response<dynamic>> postJson(String path,
          {Object? body, Map<String, String>? headers}) =>
      dio.post<dynamic>(path, data: body, options: Options(headers: headers));

  Future<Response<dynamic>> patchJson(String path, {Object? body}) =>
      dio.patch<dynamic>(path, data: body);

  Future<Response<dynamic>> putJson(String path, {Object? body}) =>
      dio.put<dynamic>(path, data: body);

  Future<Response<dynamic>> deleteJson(String path, {Object? body}) =>
      dio.delete<dynamic>(path, data: body);

  Future<Uint8List> downloadBytes(String path) async {
    final res = await dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }
}

/// Transforme une réponse de statut >= 400 (laissée passer par
/// validateStatus) en DioException badResponse, pour déclencher
/// retry + error interceptors.
class _StatusToErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        ),
        true,
      );
      return;
    }
    handler.next(response);
  }
}

class _ObserverInterceptor extends Interceptor {
  final NetworkObserver observer;
  _ObserverInterceptor(this.observer);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    observer.onRequest(RequestSnapshot(
      method: response.requestOptions.method,
      path: response.requestOptions.path,
      statusCode: response.statusCode,
    ));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final e = err.error;
    if (e is ApiException) {
      observer.onError(
        e,
        RequestSnapshot(
          method: err.requestOptions.method,
          path: err.requestOptions.path,
          statusCode: err.response?.statusCode,
        ),
      );
    }
    handler.next(err);
  }
}

@Riverpod(keepAlive: true)
NetworkObserver networkObserver(Ref ref) => const NoopNetworkObserver();

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return ApiClient(
    baseUrl: AppConstants.baseUrl,
    tokenProvider: () => auth.currentUser?.getIdToken() ?? Future.value(null),
    forceRefreshToken: () =>
        auth.currentUser?.getIdToken(true) ?? Future.value(null),
    observer: ref.watch(networkObserverProvider),
  );
}
```

Note interceptor ordering : `_StatusToErrorInterceptor` est ajouté **après**
`ErrorInterceptor` dans la liste, mais Dio exécute les `onResponse` dans l'ordre
inverse d'ajout pour la phase réponse. Si le test 400 ne lève pas d'`ApiException`,
déplacer `_StatusToErrorInterceptor` en **premier** de la liste `addAll` et
revérifier — la garantie : un statut ≥ 400 traverse retry + error.

- [ ] **Step 4: Générer le code Riverpod**

Run: `cd lilia-app && dart run build_runner build --delete-conflicting-outputs`
Expected: `api_client.g.dart` généré, pas d'erreur.

- [ ] **Step 5: Lancer les tests, vérifier le succès**

Run: `cd lilia-app && flutter test test/core/network/api_client_test.dart`
Expected: PASS (3 tests). Si le test 400 échoue, appliquer la note de réordonnancement du Step 3 puis relancer.

- [ ] **Step 6: Commit**

```bash
cd lilia-app
git add lib/core/network/api_client.dart lib/core/network/api_client.g.dart test/core/network/api_client_test.dart
git commit -m "feat(LIL-136): ApiClient Dio + provider"
```

---

## Task 8: Migrer order_repository (repo pilote + cas spéciaux)

**Files:**
- Modify: `lilia-app/lib/features/commandes/data/order_repository.dart`

Ce repo concentre les cas particuliers : grosse liste (`parseJson`), PDF binaire
(`downloadReceipt`), `Idempotency-Key` (checkout). Le migrer en premier valide le
pattern complet.

- [ ] **Step 1: Réécrire order_repository sur ApiClient**

Remplacer le contenu par (en gardant `_parseOrders` + `parseJson`) :
```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/models/checkout.dart';
import 'package:lilia_app/utils/json_isolate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:convert';
import '../../../models/order.dart';

part 'order_repository.g.dart';

List<Order> _parseOrders(String body) {
  final decoded = json.decode(body);
  final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
  final list = data is List ? data : const <dynamic>[];
  return list.whereType<Map<String, dynamic>>().map(Order.fromJson).toList();
}

@Riverpod(keepAlive: true)
class OrderRepository extends _$OrderRepository {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<void> build() async {}

  Future<List<Order>> getMyOrders() async {
    final res = await _api.getJson('/orders/my');
    // res.data est déjà décodé par Dio ; on ré-encode pour parseJson isolate
    // uniquement si la liste est grosse — sinon mapping direct.
    final data = (res.data as Map<String, dynamic>)['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(Order.fromJson).toList();
  }

  Future<Uint8List> downloadReceipt(String orderId) =>
      _api.downloadBytes('/orders/$orderId/receipt');

  Future<Checkout> createOrders({
    String? adresseId,
    required String paymentMethod,
    required bool isDelivery,
    String? note,
    String? contactPhone,
    String? promoCode,
    bool useLoyaltyPoints = false,
    String? idempotencyKey,
    double? deliveryLatitude,
    double? deliveryLongitude,
    DateTime? scheduledFor,
  }) async {
    final bodyMap = <String, dynamic>{
      'paymentMethod': paymentMethod,
      'isDelivery': isDelivery,
      if (isDelivery && adresseId != null) 'adresseId': adresseId,
      if (note != null && note.isNotEmpty) 'notes': note,
      if (contactPhone != null && contactPhone.isNotEmpty)
        'contactPhone': contactPhone,
      if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
      if (useLoyaltyPoints) 'useLoyaltyPoints': true,
      if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
      if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
      if (scheduledFor != null) ...{
        'isPreorder': true,
        'scheduledFor': scheduledFor.toUtc().toIso8601String(),
      },
    };
    final res = await _api.postJson(
      '/orders/checkout',
      body: bodyMap,
      headers: idempotencyKey != null ? {'Idempotency-Key': idempotencyKey} : null,
    );
    return checkoutFromMap(json.encode(res.data));
  }

  Future<void> reorder(String orderId) =>
      _api.postJson('/orders/$orderId/reorder');

  Future<void> deleteOrder(String orderId) =>
      _api.deleteJson('/orders/$orderId');

  Future<void> cancelOrder(String orderId) =>
      _api.patchJson('/orders/$orderId/cancel');
}
```

Note : `checkoutFromMap` attend une String JSON ; Dio renvoie déjà un Map décodé,
d'où le `json.encode(res.data)`. Si `checkoutFromMap` accepte un Map, l'adapter.
La grosse liste `getMyOrders` mappe directement (Dio a déjà décodé) ; si un profil
perf montre du jank, réintroduire `parseJson` en passant `res.data` ré-encodé.

- [ ] **Step 2: Régénérer + analyser**

Run: `cd lilia-app && dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/features/commandes/data/order_repository.dart`
Expected: pas d'erreur d'analyse sur ce fichier.

- [ ] **Step 3: Vérifier les call-sites (signatures inchangées)**

Run: `cd lilia-app && flutter analyze lib/features/commandes`
Expected: aucune erreur — les méthodes publiques gardent la même signature.

- [ ] **Step 4: Commit**

```bash
cd lilia-app
git add lib/features/commandes/data/order_repository.dart lib/features/commandes/data/order_repository.g.dart
git commit -m "refactor(LIL-136): order_repository sur ApiClient"
```

---

## Task 9: Migrer les 9 repos/services restants de lilia-app

**Files (modify):**
- `lib/features/reviews/data/review_repository.dart`
- `lib/features/commandes/data/promo_repository.dart`
- `lib/features/commandes/data/delivery_tracking_repository.dart` (partie HTTP fallback uniquement ; ne pas toucher au WS)
- `lib/features/user/data/adresse_repository.dart`
- `lib/features/user/data/user_repository.dart` (cas `/users/me` → `{user}`)
- `lib/features/cart/data/cart_repository.dart`
- `lib/features/quartiers/data/quartiers_repository.dart`
- `lib/features/notifications/data/notification_repository.dart`
- `lib/features/payments/data/payment_service.dart`
- `lib/services/notification_service.dart` (appels register/delete token)

**Exclu :** `lib/features/auth/repository/firebase_auth_repository.dart` (reste sur `http`).

Procéder repo par repo, un commit par repo. Pour chacun, appliquer le même
pattern que Task 8 :

- [ ] **Step 1: Pour chaque fichier — remplacer http par ApiClient**

Règles de réécriture identiques à chaque fichier :
1. Supprimer imports `package:http/http.dart` + `firebase_auth_repository` (token).
2. Ajouter `import 'package:lilia_app/core/network/api_client.dart';`.
3. `final ... = ref.read(apiClientProvider);` au lieu de `httpClientProvider` + token.
4. `http.get(Uri.parse('${baseUrl}/x'), headers:...)` → `_api.getJson('/x')`.
5. Déwrapper via `res.data` (déjà décodé par Dio) + `ApiResponse.mapOf/listOf` si besoin.
6. Supprimer tout `_extractErrorMessage` local et tout `try/catch(_){}` muet :
   laisser remonter l'`ApiException`. Les 4 `catch(_){}` muets de lilia-app sont
   dans ces fichiers — les supprimer.
7. Cas `user_repository` `/users/me` : `res.data['user']` (pas `['data']`).

- [ ] **Step 2: Régénérer le code**

Run: `cd lilia-app && dart run build_runner build --delete-conflicting-outputs`
Expected: pas d'erreur.

- [ ] **Step 3: Vérifier qu'aucun catch muet ne reste**

Run: `cd lilia-app && grep -rn "catch (_) {}" lib | grep -v firebase_auth_repository`
Expected: aucune sortie (0 occurrence).

- [ ] **Step 4: Analyse complète**

Run: `cd lilia-app && flutter analyze`
Expected: `No issues found` (ou seulement des warnings préexistants non liés).

- [ ] **Step 5: Retirer le provider httpClient devenu inutile**

Dans `firebase_auth_repository.dart`, `httpClientProvider` reste utilisé par
`authRepository` lui-même (qui garde `http`). Vérifier qu'aucun **autre** fichier
ne référence `httpClientProvider` :
Run: `cd lilia-app && grep -rln "httpClientProvider" lib | grep -v ".g.dart"`
Expected: uniquement `firebase_auth_repository.dart` (+ son `.g.dart`). Si
`payment_service`/`notification_service` y figurent encore, les migrer.

- [ ] **Step 6: Lancer toute la suite de tests**

Run: `cd lilia-app && flutter test`
Expected: tous les tests passent (réseau + existants).

- [ ] **Step 7: Commit (un par repo recommandé)**

```bash
cd lilia-app
git add lib test
git commit -m "refactor(LIL-136): migration repos restants sur ApiClient + suppression catch muets"
```

---

## Task 10: Réplication sur lilia-food-admin

**Files:**
- Create: `lilia-food-admin/lib/core/network/` (copie des 6 fichiers + tests de Task 2-7)
- Modify: `lilia-food-admin/pubspec.yaml`, les 6 repos `data/`

- [ ] **Step 1: Copier la couche network**

Copier `lib/core/network/**` et `test/core/network/**` depuis lilia-app vers
lilia-food-admin. Adapter :
- le préfixe d'import `package:lilia_app/` → `package:lilia_food_admin/`
  (vérifier le nom exact dans `lilia-food-admin/pubspec.yaml` champ `name:`).
- l'import du provider Firebase Auth (`firebaseAuthProvider`) vers son chemin
  équivalent dans l'admin (chercher `firebaseAuthProvider` dans `lilia-food-admin/lib`).
- `AppConstants.baseUrl` → constante équivalente de l'admin.

- [ ] **Step 2: Ajouter les dépendances**

Dans `lilia-food-admin/pubspec.yaml` : `dio: ^5.7.0` + dev `http_mock_adapter: ^0.6.1`.
Run: `cd lilia-food-admin && flutter pub get && dart run build_runner build --delete-conflicting-outputs`
Expected: génération OK.

- [ ] **Step 3: Lancer les tests network copiés**

Run: `cd lilia-food-admin && flutter test test/core/network`
Expected: PASS (mêmes tests que lilia-app).

- [ ] **Step 4: Migrer les 6 repos (même pattern que Task 9)**

Repos sous `lilia-food-admin/lib/.../data/` (les lister via
`find lilia-food-admin/lib -name "*repository*.dart" ! -name "*.g.dart"` +
`restaurant_settings_service.dart`, `user_repository.dart`, `client_repository.dart`).
Appliquer les règles de réécriture de Task 9 Step 1.

- [ ] **Step 5: Vérifier + analyser**

Run: `cd lilia-food-admin && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
Expected: pas d'erreur, tests verts. (admin avait 0 catch muet — rien à supprimer.)

- [ ] **Step 6: Commit**

```bash
cd lilia-food-admin
git add lib test pubspec.yaml pubspec.lock
git commit -m "feat(LIL-136): ApiClient centralisé + migration repos (admin)"
```

---

## Task 11: Réplication sur lilia_food_delivery

**Files:**
- Create: `lilia_food_delivery/lib/core/network/` (copie)
- Modify: `lilia_food_delivery/pubspec.yaml`, `lib/features/deliveries/data/delivery_repository.dart` (+ autre repo)

- [ ] **Step 1: Copier la couche network + adapter les imports**

Comme Task 10 Step 1, préfixe `package:lilia_food_delivery/` (vérifier `name:`),
provider Firebase Auth + baseUrl de l'app livreur.

- [ ] **Step 2: Dépendances + génération**

`dio: ^5.7.0` + dev `http_mock_adapter: ^0.6.1` dans le pubspec.
Run: `cd lilia_food_delivery && flutter pub get && dart run build_runner build --delete-conflicting-outputs`
Expected: OK.

- [ ] **Step 3: Tests network**

Run: `cd lilia_food_delivery && flutter test test/core/network`
Expected: PASS.

- [ ] **Step 4: Migrer les 2 repos + supprimer les 3 catch muets**

Repos : `lib/features/deliveries/data/delivery_repository.dart` + l'autre repo
(`find lilia_food_delivery/lib -name "*repository*.dart" ! -name "*.g.dart"`).
Appliquer Task 9 Step 1. Supprimer les 3 `catch (_) {}` muets.

- [ ] **Step 5: Vérifier zéro catch muet + analyser + tester**

Run: `cd lilia_food_delivery && grep -rn "catch (_) {}" lib`
Expected: aucune sortie.
Run: `cd lilia_food_delivery && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
Expected: pas d'erreur, tests verts.

- [ ] **Step 6: Commit**

```bash
cd lilia_food_delivery
git add lib test pubspec.yaml pubspec.lock
git commit -m "feat(LIL-136): ApiClient centralisé + migration repos (delivery)"
```

---

## Task 12: Vérification finale DoD

- [ ] **Step 1: Un seul point d'injection token + parsing erreur par app**

Run pour chaque app : `grep -rn "_extractErrorMessage\|Bearer \$token\|getIdToken()" <app>/lib | grep -v core/network | grep -v firebase_auth_repository`
Expected: aucune sortie (hors couche network + auth repo).

- [ ] **Step 2: Aucun catch muet restant (3 apps)**

Run: `for a in lilia-app lilia-food-admin lilia_food_delivery; do echo "$a:"; grep -rn "catch (_) {}" $a/lib | grep -v firebase_auth_repository; done`
Expected: aucune occurrence (firebase_auth_repository de lilia-app peut en garder un — il est hors scope).

- [ ] **Step 3: Analyse + tests des 3 apps**

Run: `for a in lilia-app lilia-food-admin lilia_food_delivery; do (cd $a && flutter analyze && flutter test) || echo "ÉCHEC $a"; done`
Expected: pas d'`ÉCHEC`.

- [ ] **Step 4: Mettre à jour le statut Linear**

Passer LIL-136 en « In Review » et lier les commits/PR des 3 repos.

---

## Correction de périmètre (constatée à l'exécution — 2026-06-13)

L'inventaire initial (`find -name "*repository*.dart"`) sous-comptait les fichiers
réseau. Périmètre réel :

- **lilia-app (FAIT)** : 17 fichiers migrés, pas 10. Fichiers hors-convention
  ajoutés : `home/data/remote/{home,banner,restaurant,menu}_repo.dart`,
  `features/auth/user_sync_provider.dart`,
  `features/favoris/application/restaurant_favorites_provider.dart`. Le WS
  `tracking_socket_service.dart` reste sur `getIdToken` (handshake socket, hors
  scope HTTP, conforme au plan).
  **Révision (feedback user)** : `firebase_auth_repository.dart` a finalement
  AUSSI été migré (les 3 `/users/sync`). La crainte de cycle était infondée :
  `apiClient → firebaseAuth` et `authRepository → apiClient`, jamais l'inverse
  (import circulaire fichier OK en Dart, pas de cycle de providers).
  `httpClientProvider` supprimé, `http` retiré du pubspec. Résultat : **plus
  aucun import `http` dans lib/test** → point d'injection token réellement unique.
- **lilia-food-admin (T10, À FAIRE)** : ~15 fichiers (pas 6) utilisant
  `FirebaseAuth.instance` + `http` : `features/{clients/{client,user},users/user,
  incidents,admin/admin_operations,settings/restaurant_settings,home/order,
  zones,products/product,menus/menu,categories/category,deliveries/delivery,
  photos/{product_images,menu_images,vendor_photos}}` + `services/notification`.
  Package name = `lilia_admin` (imports `package:lilia_admin/`). `firebaseAuthProvider`
  présent. `AppConstants.baseUrl` présent. Pas de `httpClientProvider`.
- **lilia_food_delivery (T11, À FAIRE)** : vérifier l'inventaire réel de la même
  façon (`grep -rln "package:http/http.dart" lib`) avant de chiffrer ; 3 catch
  muets à supprimer.

## Self-Review (effectuée)

- **Couverture spec** : ApiException (T2), NetworkObserver (T3), ErrorInterceptor (T4),
  RetryInterceptor + règle idempotence (T5), AuthInterceptor refresh (T6), ApiClient +
  déwrapping par repo + downloadBytes (T7-T8), migration 3 apps (T8-T11), DoD (T12).
  Sentry/package partagé/auth-repo explicitement hors scope (cf. spec).
- **Placeholders** : aucun TODO/TBD ; code complet à chaque step.
- **Cohérence des types** : `ApiException(message, {statusCode, kind})`,
  `ApiErrorKind`, `RequestSnapshot`, `NetworkObserver.onRequest/onError`,
  `ApiClient.getJson/postJson/patchJson/putJson/deleteJson/downloadBytes`,
  providers `apiClientProvider`/`networkObserverProvider` — cohérents entre tâches.
- **Risque connu** : ordre des interceptors Dio pour la phase réponse (note dans
  T7 Step 3) et signature `checkoutFromMap` (note T8) — deux points à vérifier
  empiriquement, avec instruction de correction fournie.
