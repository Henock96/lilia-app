// M-04 — une panne réseau n'est pas « aucun favori ».
//
// `_fetchFromBackend` attrapait **toute** `ApiException` et rendait `[]`, avec
// le commentaire « favoris = feature non bloquante ». Conséquence : quand le
// backend est en panne, l'écran affiche l'état vide soigné — « Aucun
// restaurant en favoris », « Explorez et ajoutez vos restaurants préférés » —
// à un client qui en a peut-être douze. Et le provider est `keepAlive` : cet
// état vide reste affiché jusqu'à une invalidation explicite.
//
// L'écran a toujours eu une branche `error:` ; elle était simplement
// inatteignable.
//
// ⚠️ Ces tests observent l'**AsyncValue** du provider, pas son `.future` :
// c'est ce que lit `favoris_page` (`favorites.when(...)`), et c'est donc là
// que se joue la distinction chargement / erreur / vide / données.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/network/interceptors/retry_interceptor.dart';
import 'package:lilia_app/features/favoris/application/restaurant_favorites_provider.dart';
import 'package:lilia_app/models/restaurant.dart';

void main() {
  late ProviderContainer container;

  /// Monte le provider au-dessus d'un client sans réseau.
  ///
  /// `RetryInterceptor` est retiré : sa politique a son propre fichier de
  /// tests, et on veut observer ici la **décision des favoris** face à une
  /// erreur, pas attendre trois tentatives.
  void monter(HttpClientAdapter adapter) {
    final client = ApiClient(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'jeton',
      forceRefreshToken: () async => 'jeton',
    );
    client.dio.interceptors.removeWhere((i) => i is RetryInterceptor);
    client.dio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    container.listen(
      restaurantFavoritesProvider,
      (_, _) {},
      onError: (_, _) {},
    );
  }

  tearDown(() => container.dispose());

  /// Laisse la requête se dérouler, puis rend l'état observé par l'écran.
  Future<AsyncValue<List<RestaurantSummary>>> etat() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final v = container.read(restaurantFavoritesProvider);
      if (v.hasError || v.hasValue) return v;
    }
    return container.read(restaurantFavoritesProvider);
  }

  test('500 → erreur, et surtout pas une liste vide', () async {
    monter(_StubAdapter(500, '{"message":"Service indisponible"}'));

    final v = await etat();

    expect(v.hasError, isTrue);
    expect(v.error, isA<ApiException>());
    expect(
      v.hasValue,
      isFalse,
      reason: 'une liste vide ferait dire à l’écran « aucun favori »',
    );
  });

  test('403 → erreur', () async {
    monter(_StubAdapter(403, '{"message":"Interdit"}'));

    expect((await etat()).hasError, isTrue);
  });

  test('panne réseau → erreur de type réseau', () async {
    monter(_FailingAdapter());

    final v = await etat();

    expect(v.hasError, isTrue);
    expect((v.error! as ApiException).kind, ApiErrorKind.network);
  });

  /// La seule exception tolérée : sans session, il n'y a pas de favoris à
  /// montrer, et ce n'est pas une panne. Afficher une erreur rouge à un
  /// visiteur non connecté serait un faux positif.
  test('401 → liste vide, sans erreur', () async {
    monter(_StubAdapter(401, '{"message":"Unauthorized"}'));

    final v = await etat();

    expect(v.hasError, isFalse);
    expect(v.value, isEmpty);
  });

  test('200 → la liste est lue normalement', () async {
    monter(
      _StubAdapter(
        200,
        '{"data":[{"id":"v1","nom":"Chez Lilia","adresse":"Poto-Poto"}]}',
      ),
    );

    final v = await etat();

    expect(v.hasError, isFalse);
    expect(v.value, hasLength(1));
    expect(v.value!.single.name, 'Chez Lilia');
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'réseau indisponible',
  );

  @override
  void close({bool force = false}) {}
}
