import 'dart:typed_data';

import 'package:dio/dio.dart';
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
///
/// Sur erreur, l'ApiClient ne propage jamais de [DioException] : il lève
/// toujours une [ApiException] (message FR prêt à afficher) et notifie
/// l'observateur.
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
      ),
    );
    dio.interceptors.addAll([
      AuthInterceptor(dio,
          tokenProvider: tokenProvider, forceRefreshToken: forceRefreshToken),
      RetryInterceptor(dio),
      ErrorInterceptor(),
    ]);
    return ApiClient._(dio, observer);
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
      _run(() => dio.get<dynamic>(path, queryParameters: query));

  /// Renvoie le corps brut (String non décodée) — pour le parsing déporté sur
  /// isolate via `parseJson` sur les grosses listes (préserve l'optim perf).
  Future<String> getText(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await dio.get<String>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain),
      );
      _observer.onRequest(_snap(res.requestOptions, res.statusCode));
      return res.data ?? '';
    } on DioException catch (e) {
      throw _report(e);
    }
  }

  Future<Response<dynamic>> postJson(String path,
          {Object? body, Map<String, String>? headers}) =>
      _run(() =>
          dio.post<dynamic>(path, data: body, options: Options(headers: headers)));

  Future<Response<dynamic>> patchJson(String path, {Object? body}) =>
      _run(() => dio.patch<dynamic>(path, data: body));

  Future<Response<dynamic>> putJson(String path, {Object? body}) =>
      _run(() => dio.put<dynamic>(path, data: body));

  Future<Response<dynamic>> deleteJson(String path, {Object? body}) =>
      _run(() => dio.delete<dynamic>(path, data: body));

  Future<Uint8List> downloadBytes(String path) async {
    try {
      final res = await dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      _observer.onRequest(_snap(res.requestOptions, res.statusCode));
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw _report(e);
    }
  }

  Future<Response<dynamic>> _run(
      Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      _observer.onRequest(_snap(res.requestOptions, res.statusCode));
      return res;
    } on DioException catch (e) {
      throw _report(e);
    }
  }

  /// Extrait l'[ApiException] (posée par l'ErrorInterceptor), notifie
  /// l'observateur, et la renvoie pour qu'elle soit levée.
  ApiException _report(DioException e) {
    final api = e.error is ApiException
        ? e.error as ApiException
        : const ApiException('Une erreur est survenue. Réessayez.');
    _observer.onError(api, _snap(e.requestOptions, e.response?.statusCode));
    return api;
  }

  RequestSnapshot _snap(RequestOptions o, int? status) =>
      RequestSnapshot(method: o.method, path: o.path, statusCode: status);
}

@Riverpod(keepAlive: true)
NetworkObserver networkObserver(Ref ref) => const NoopNetworkObserver();

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return ApiClient(
    baseUrl: AppConstants.baseUrl,
    tokenProvider: () async =>
        auth.currentUser == null ? null : await auth.currentUser!.getIdToken(),
    forceRefreshToken: () async => auth.currentUser == null
        ? null
        : await auth.currentUser!.getIdToken(true),
    observer: ref.watch(networkObserverProvider),
  );
}
