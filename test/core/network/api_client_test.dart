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
      a.onGet('/orders/my', (s) => s.reply(200, {'data': <dynamic>[], 'count': 0}));
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

  test('getText renvoie le corps brut non décodé', () async {
    final client = buildClient((a) {
      a.onGet('/orders/my', (s) => s.reply(200, {'data': <dynamic>[], 'count': 0}));
    });
    final body = await client.getText('/orders/my');
    expect(body, contains('"count":0'));
  });

  test('downloadBytes renvoie les octets', () async {
    final client = buildClient((a) {
      a.onGet('/orders/1/receipt', (s) => s.reply(200, [37, 80, 68, 70]));
    });
    final bytes = await client.downloadBytes('/orders/1/receipt');
    expect(bytes, isNotEmpty);
  });
}
