// Lecture du panier — le **vrai** `CartRepository`.
//
// `GET /cart` répond 404 tant que le compte n'a rien ajouté : le serveur ne crée
// le panier qu'au premier `POST /cart/add`. C'est donc l'état de tout nouvel
// inscrit, et le faux dépôt de `guest_cart_test.dart` le traduit par `null`. Le
// vrai levait, et la reprise du panier visiteur échouait juste après
// l'inscription.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CartRepository depot({required int statut, required String corps}) {
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'jeton',
      forceRefreshToken: () async => 'jeton',
    );
    api.dio.httpClientAdapter = _FauxServeur(statut, corps);
    return CartRepository(api);
  }

  test('aucun panier (404) : panier vide, pas une panne', () async {
    final repo = depot(
      statut: 404,
      corps: '{"success":false,"message":"Panier non trouvé."}',
    );

    expect(await repo.getCart(), isNull);
  });

  test('compte non synchronisé (403) : remonte à la garde de session', () {
    final repo = depot(
      statut: 403,
      corps: '{"success":false,"message":"Compte non synchronisé",'
          '"error":{"code":"ACCOUNT_NOT_SYNCED"}}',
    );

    expect(repo.getCart(), throwsA(isA<ApiException>()));
  });
}

class _FauxServeur implements HttpClientAdapter {
  _FauxServeur(this.statut, this.corps);

  final int statut;
  final String corps;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        corps,
        statut,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
