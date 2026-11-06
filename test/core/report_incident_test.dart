import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/log.dart';
import 'package:lilia_app/core/network/api_exception.dart';

import 'sentry_espion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int> incidentsPour(Object erreur) async {
    final incidents = await espionnerSentry();
    reportIncident('Essai', erreur, StackTrace.current);
    await laisserPartirSentry();
    return incidents.length;
  }

  test('une panne serveur part vers Sentry, avec son contexte', () async {
    final incidents = await espionnerSentry();

    reportIncident(
      'Essai',
      const ApiException('panne', kind: ApiErrorKind.server, statusCode: 500),
      StackTrace.current,
    );
    await laisserPartirSentry();

    expect(incidents.single.tags?['contexte'], 'Essai');
  });

  test('une erreur inattendue part aussi', () async {
    expect(await incidentsPour(StateError('inattendu')), 1);
  });

  test('une coupure réseau reste hors du journal', () async {
    expect(
      await incidentsPour(
        const ApiException('coupure', kind: ApiErrorKind.network),
      ),
      0,
    );
  });

  test('un délai dépassé aussi', () async {
    expect(
      await incidentsPour(
        const ApiException('délai', kind: ApiErrorKind.timeout),
      ),
      0,
    );
  });
}
