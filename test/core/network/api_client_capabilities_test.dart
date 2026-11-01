import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';

/// Capacités annoncées au serveur par chaque requête de l'app client.
///
/// Le serveur ne conduit un parcours que si l'application l'annonce :
/// paiement piloté par le prestataire (`provider`), et — durcissement lot 3 —
/// « accepter puis payer » (`accept-first`). Retirer l'une d'elles, c'est
/// revenir silencieusement au comportement d'une version antérieure.
void main() {
  test('annonce les deux capacités, sur toutes les requêtes', () {
    final client = ApiClient(
      baseUrl: 'https://test.local',
      tokenProvider: () async => null,
      forceRefreshToken: () async => null,
    );
    final headers = client.dio.options.headers;
    expect(headers['X-Lilia-Payment-Flow'], 'provider');
    expect(headers['X-Lilia-Order-Flow'], 'accept-first');
  });
}
