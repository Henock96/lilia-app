import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';

/// Latence serveur mesurée sur la production le 08/09/2026, cas le plus
/// favorable (connexion keep-alive réutilisée). Voir l'en-tête de
/// `add_to_cart_latency_test.dart`.
const int kLatenceServeurMesureeMs = 930;

/// Réponse que le serveur de banc doit produire pour une requête donnée.
sealed class BenchReponse {
  const BenchReponse();
}

/// Le panier courant du serveur, après application de la mutation.
class BenchOk extends BenchReponse {
  /// Latence spécifique à cette réponse — sert à provoquer des retours dans le
  /// désordre.
  final int? latenceMs;
  const BenchOk({this.latenceMs});
}

/// Une erreur HTTP.
class BenchErreur extends BenchReponse {
  final int status;
  final String message;
  final int? latenceMs;
  const BenchErreur(this.status, this.message, {this.latenceMs});
}

/// Un silence : la requête n'obtient jamais de réponse (timeout côté client).
class BenchSilence extends BenchReponse {
  const BenchSilence();
}

/// Un 200 dont le corps n'est pas un panier — proxy qui réécrit, déploiement
/// incohérent, page d'erreur HTML. `_cartFromData` rend alors `null`.
class BenchCorpsInvalide extends BenchReponse {
  const BenchCorpsInvalide();
}

/// Serveur HTTP local qui rejoue le contrat réel de `/cart`.
///
/// Il tient un panier en mémoire et applique réellement les mutations, de
/// sorte que la quantité finale observée par les tests est celle qu'un vrai
/// backend produirait — y compris après plusieurs mutations concurrentes.
class CartBench {
  final HttpServer _server;
  final Map<String, int> _quantites;

  /// Journal des requêtes reçues, dans l'ordre d'arrivée.
  final List<String> appels = [];

  /// Latence par défaut appliquée à chaque requête.
  int latenceMs;

  /// Réponses forcées, consommées dans l'ordre. Quand la file est vide, on
  /// retombe sur [reponseParDefaut].
  final List<BenchReponse> reponsesForcees = [];

  /// Réponse servie quand [reponsesForcees] est vide.
  ///
  /// Utile pour les pannes durables : `RetryInterceptor` rejoue les méthodes
  /// idempotentes (GET/PUT/PATCH/DELETE) jusqu'à 3 fois sur 5xx. Une erreur
  /// posée en un seul exemplaire serait donc absorbée par la seconde
  /// tentative — et le test vérifierait le contraire de ce qu'il croit.
  BenchReponse reponseParDefaut = const BenchOk();

  late final CartRepository repository;

  CartBench._(this._server, this._quantites, this.latenceMs);

  int get nombreRequetes => appels.length;

  /// Quantité actuellement enregistrée côté « serveur » pour une variante.
  int quantiteServeur(String variantId) => _quantites[variantId] ?? 0;

  void reset() => appels.clear();

  static Future<CartBench> demarrer({
    int latenceMs = kLatenceServeurMesureeMs,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final bench = CartBench._(server, <String, int>{}, latenceMs);
    bench.repository = CartRepository(
      ApiClient.test(
        baseUrl: 'http://127.0.0.1:${server.port}',
        tokenProvider: () async => 'fake-token',
        forceRefreshToken: () async => 'fake-token',
      ),
    );
    unawaited(bench._servir());
    return bench;
  }

  Future<void> _servir() async {
    // ⚠️ Chaque requête est traitée **en parallèle**. Les attendre l'une après
    // l'autre sérialiserait le serveur : les latences par réponse ne
    // produiraient alors jamais de retour dans le désordre, et le test censé
    // le vérifier passerait sans rien vérifier.
    await for (final req in _server) {
      unawaited(_traiter(req));
    }
  }

  Future<void> _traiter(HttpRequest req) async {
    {
      final chemin = req.uri.path;
      final methode = req.method;
      appels.add('$methode $chemin');

      final forcee = reponsesForcees.isEmpty
          ? reponseParDefaut
          : reponsesForcees.removeAt(0);

      if (forcee is BenchSilence) return; // jamais de réponse

      final corps = await utf8.decoder.bind(req).join();

      final attente = switch (forcee) {
        BenchOk(:final latenceMs) => latenceMs,
        BenchErreur(:final latenceMs) => latenceMs,
        BenchSilence() || BenchCorpsInvalide() => null,
      };
      await Future<void>.delayed(Duration(milliseconds: attente ?? latenceMs));

      if (forcee is BenchErreur) {
        req.response
          ..statusCode = forcee.status
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({'success': false, 'message': forcee.message}),
          );
        await req.response.close();
        return;
      }

      if (forcee is BenchCorpsInvalide) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'success': true, 'data': 'pas un panier'}));
        await req.response.close();
        return;
      }

      _appliquer(methode, chemin, corps);

      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'success': true, 'data': _corpsReponse(chemin)}));
      await req.response.close();
    }
  }

  void _appliquer(String methode, String chemin, String corps) {
    final json = corps.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(corps) as Map<String, dynamic>;

    if (methode == 'POST' && chemin == '/cart/add') {
      final variantId = json['variantId'] as String;
      final q = json['quantite'] as int;
      _quantites[variantId] = (_quantites[variantId] ?? 0) + q;
    } else if (methode == 'PATCH' && chemin.startsWith('/cart/items/')) {
      final variantId = _variantDepuisItemId(chemin);
      _quantites[variantId] = json['quantite'] as int;
    } else if (methode == 'DELETE' && chemin.startsWith('/cart/items/')) {
      _quantites.remove(_variantDepuisItemId(chemin));
    } else if (methode == 'DELETE' && chemin == '/cart/clear') {
      _quantites.clear();
    } else if (methode == 'POST' && chemin.endsWith('/reorder')) {
      _quantites['var-1'] = (_quantites['var-1'] ?? 0) + 1;
    }
  }

  /// Le banc nomme les lignes de panier `item-<variantId>` — stable et lisible.
  String _variantDepuisItemId(String chemin) =>
      chemin.split('/').last.replaceFirst('item-', '');

  Object _corpsReponse(String chemin) =>
      chemin.endsWith('/reorder') ? {'added': 1, 'unavailable': 0} : panier();

  /// Le panier tel que le serveur le renverrait maintenant.
  Map<String, dynamic> panier() => {
    'id': 'cart-1',
    'userId': 'user-1',
    'createdAt': '2026-09-08T10:00:00.000Z',
    'updatedAt': '2026-09-08T10:00:00.000Z',
    'items': [
      for (final entry in _quantites.entries)
        if (entry.value > 0)
          {
            'id': 'item-${entry.key}',
            'cartId': 'cart-1',
            'productId': 'prod-${entry.key}',
            'variantId': entry.key,
            'menuId': null,
            'quantite': entry.value,
            'createdAt': '2026-09-08T10:00:00.000Z',
            'product': {
              'nom': 'Poulet braisé',
              'imageUrl': null,
              'restaurantId': 'resto-1',
              'madeToOrder': false,
              'stockRestant': null,
            },
            'variant': {'label': 'Normale', 'prix': 3500},
          },
    ],
  };

  Future<void> fermer() => _server.close(force: true);
}
