import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/user/data/user_repository.dart';

/// Suppression de compte — le refus du serveur doit **remonter**.
///
/// Le backend répond 409 quand la suppression laisserait une transaction sans
/// interlocuteur : commande en cours, boutique possédée, livraison en cours.
/// `AuthController.deleteAccount` avalait ce refus (`catch { debugPrint }`)
/// puis supprimait quand même le compte Firebase — le client perdait
/// définitivement l'accès à une commande qui était en train d'être livrée,
/// et sa ligne restait `ACTIVE` en base. Un état qu'aucun écran ne pouvait
/// plus rattraper, et qui était documenté depuis août sans être corrigé.
///
/// Ces tests portent sur `UserRepository`, seul point où la réponse du serveur
/// est traduite : ils fixent ce qui doit passer et ce qui doit être relayé.
void main() {
  late Dio dio;
  late UserRepository repo;
  late List<RequestOptions> requests;

  /// Adaptateur qui rend le statut demandé, sans réseau.
  void respondWith(int status, {String message = 'Erreur'}) {
    dio.httpClientAdapter = _StubAdapter(
      status: status,
      body: '{"success":false,"message":"$message"}',
      onRequest: requests.add,
    );
  }

  setUp(() {
    requests = [];
    // `ApiClient` construit son propre Dio (interceptors auth/retry/erreur) :
    // on passe par la fabrique publique, puis on remplace l'adaptateur réseau.
    // Tester le repository à travers la vraie chaîne d'interceptors est
    // précisément ce qui compte ici — c'est `ErrorInterceptor` qui traduit le
    // statut HTTP en `ApiException`.
    final client = ApiClient(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'jeton',
      forceRefreshToken: () async => 'jeton',
    );
    dio = client.dio;
    repo = UserRepository(client);
  });

  test('204 → suppression acceptée, aucune exception', () async {
    dio.httpClientAdapter = _StubAdapter(
      status: 200,
      body: '{"success":true}',
      onRequest: requests.add,
    );

    await expectLater(repo.deleteAccount(), completes);
    expect(requests.single.method, 'DELETE');
    expect(requests.single.path, '/users/me');
  });

  /// Le seul refus toléré. La route a pu ne pas encore être déployée, ou le
  /// compte être déjà purgé : dans les deux cas il n'y a rien à protéger.
  test('404 → toléré (route absente ou compte déjà purgé)', () async {
    respondWith(404);
    await expectLater(repo.deleteAccount(), completes);
  });

  /// Le cas qui compte. Le message du serveur nomme la commande ou la
  /// boutique en cause : il doit arriver jusqu'à l'utilisateur, pas être
  /// remplacé par un générique — et surtout pas être avalé.
  test('409 → relayé, avec le message du serveur', () async {
    respondWith(
      409,
      message: 'Vous avez 1 commande(s) en cours.',
    );

    await expectLater(
      repo.deleteAccount(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', contains('commande')),
      ),
    );
  });

  test('500 → relayé (une panne serveur n’autorise pas à effacer)', () async {
    respondWith(500);
    await expectLater(repo.deleteAccount(), throwsA(isA<ApiException>()));
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    required this.status,
    required this.body,
    required this.onRequest,
  });

  final int status;
  final String body;
  final void Function(RequestOptions) onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
