// **Le barème se périme.**
//
// `platformSettingsProvider` était `@Riverpod(keepAlive: true)` sans
// expiration : une fois obtenu, il valait « pour la session ». Or une session
// Android dure des heures — le processus survit aux mises en arrière-plan —
// pendant que le serveur, lui, ne garde sa propre copie que soixante secondes
// (`PlatformSettingsService.CACHE_TTL_MS`).
//
// Un administrateur qui change la commission pendant qu'un client a
// l'application ouverte : le serveur facture le nouveau taux au bout d'une
// minute, le client continue d'afficher l'ancien. C'est le même écart
// « total validé ≠ montant réclamé » que le repli codé en dur qu'on avait
// supprimé, avec une fenêtre plus étroite.
//
// Deux garanties à tenir, et elles tirent en sens contraire :
//   · naviguer d'écran en écran ne doit coûter aucun appel ;
//   · reprendre l'application après une longue pause doit relire.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/utils/provider_cache.dart';

/// Compte les appels réellement partis sur le réseau.
class _AdaptateurCompteur implements HttpClientAdapter {
  int appels = 0;
  double serviceFeePercent = 15;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    appels++;
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'serviceFeePercent': serviceFeePercent,
          'loyaltyPointsPerOrder': 1,
          'loyaltyPointValueXaf': 100,
          'loyaltyMinRedemption': 1,
          'referrerBonusPoints': 1,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Horodatage pilotable — à la place de celui qui observe le cycle de vie.
///
/// Le seuil des cinq minutes appartient à `StaleForegroundStamp` et a ses
/// propres tests. Ce qu'on éprouve ici est le **câblage** : le barème
/// réagit-il, ou pas, quand l'horodatage bouge.
class _HorodatagePilotable extends StaleForegroundStamp {
  @override
  DateTime build() => DateTime(2026, 9, 21, 8);

  void reprisesTardive() => state = DateTime(2026, 9, 21, 14);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AdaptateurCompteur reseau;
  late ProviderContainer container;

  setUp(() {
    reseau = _AdaptateurCompteur();
    final client = ApiClient(
      baseUrl: 'https://api.test',
      tokenProvider: () async => null,
      forceRefreshToken: () async => null,
    );
    client.dio.httpClientAdapter = reseau;
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        staleForegroundStampProvider.overrideWith(_HorodatagePilotable.new),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Abonner puis désabonner : c'est ce que fait un écran qui part et revient.
  Future<void> visiterUnEcranMonetaire() async {
    final abonnement = container.listen(platformSettingsProvider, (_, _) {});
    await container.read(platformSettingsProvider.future);
    abonnement.close();
    await Future<void>.delayed(Duration.zero);
  }

  test('naviguer d’écran en écran ne redemande pas le barème', () async {
    await visiterUnEcranMonetaire();
    await visiterUnEcranMonetaire();
    await visiterUnEcranMonetaire();

    expect(
      reseau.appels,
      1,
      reason: 'le checkout lit le barème à chaque frame de ses écrans : sans '
          'cache, chaque aller-retour coûterait un appel sur la 4G de '
          'Brazzaville',
    );
  });

  test('une reprise tardive de l’application relit le barème', () async {
    final abonnement = container.listen(platformSettingsProvider, (_, _) {});
    final premier = await container.read(platformSettingsProvider.future);
    expect(premier.serviceFeePercent, 15);
    expect(reseau.appels, 1);

    // L'administrateur change la commission pendant que le téléphone dort.
    reseau.serviceFeePercent = 20;

    (container.read(staleForegroundStampProvider.notifier)
            as _HorodatagePilotable)
        .reprisesTardive();
    await Future<void>.delayed(Duration.zero);

    final second = await container.read(platformSettingsProvider.future);
    expect(
      reseau.appels,
      2,
      reason: 'reprendre l’application est exactement le moment où le client '
          'regarde à nouveau son total',
    );
    expect(
      second.serviceFeePercent,
      20,
      reason: 'le nouveau barème doit atteindre l’écran, pas rester au serveur',
    );
    abonnement.close();
  });
}
