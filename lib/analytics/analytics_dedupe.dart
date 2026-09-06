import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Déduplication — deux mécanismes, parce qu'il y a deux problèmes distincts.
///
/// **1. Le bruit de cycle de vie** (`RepeatGuard`). Un `build()` Flutter est
/// rejoué à chaque changement d'état — thème, clavier, arrivée d'une réponse
/// réseau, notification. Un événement posé dans un `build` part alors dix fois
/// pour une seule consultation. Une fenêtre courte sur la signature
/// `événement + paramètres` absorbe ces rejeux sans masquer une seconde
/// consultation réelle, qui arrive forcément plus tard.
///
/// **2. L'unicité métier** (`OnceRegistry`). `payment_success` doit être compté
/// une fois par paiement, pour toujours : le client rouvre le détail de sa
/// commande, revient dessus une semaine plus tard depuis une notification, ou
/// le serveur reçoit un webhook rejoué. Une fenêtre de temps ne protège pas de
/// ça — il faut une trace persistante, indexée sur l'identifiant métier.
///
/// Les deux structures reçoivent leur horloge et leur stockage par injection :
/// une garantie annoncée doit pouvoir être testée sans attendre.

/// Signature stable d'un envoi — l'ordre des clés ne doit pas la changer.
String analyticsSignature(String event, Map<String, Object> params) {
  final keys = params.keys.toList()..sort();
  final body = keys.map((k) => '$k=${params[k]}').join('&');
  return '$event|$body';
}

/// Absorbe les rejeux d'interface : même signature, à moins de [window].
///
/// ⚠️ La fenêtre est volontairement **courte** (une seconde). Une fenêtre
/// longue supprimerait de vraies consultations répétées — un client qui compare
/// deux fois la même fiche produit consulte bien deux fois.
class RepeatGuard {
  RepeatGuard({
    this.window = const Duration(seconds: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;
  final Map<String, DateTime> _seen = {};

  /// `true` si l'envoi doit être laissé passer.
  bool allow(String signature) {
    final t = _now();
    final last = _seen[signature];
    if (last != null && t.difference(last) < window) return false;
    _seen[signature] = t;
    _prune(t);
    return true;
  }

  /// Empêche la carte de croître indéfiniment sur une session longue.
  void _prune(DateTime t) {
    if (_seen.length < 200) return;
    _seen.removeWhere((_, at) => t.difference(at) >= window);
  }
}

/// Stockage clé/valeur minimal — `SharedPreferences` en production, une carte
/// en test.
abstract interface class AnalyticsKeyStore {
  List<String>? read(String key);
  void write(String key, List<String> value);
}

/// Implémentation en mémoire, pour les tests et comme repli tant que
/// `SharedPreferences` n'est pas chargé.
class InMemoryKeyStore implements AnalyticsKeyStore {
  final Map<String, List<String>> _data = {};

  @override
  List<String>? read(String key) => _data[key];

  @override
  void write(String key, List<String> value) => _data[key] = value;
}

/// Implémentation persistante.
///
/// Le chargement de `SharedPreferences` est asynchrone ; le registre, lui, doit
/// répondre immédiatement — un événement ne peut pas attendre le disque. On
/// garde donc une copie en mémoire, hydratée au démarrage, et l'écriture disque
/// part sans être attendue.
class SharedPrefsKeyStore implements AnalyticsKeyStore {
  SharedPrefsKeyStore(this._prefs);

  final SharedPreferences _prefs;
  final Map<String, List<String>> _cache = {};

  @override
  List<String>? read(String key) =>
      _cache[key] ??= _prefs.getStringList(key) ?? const [];

  @override
  void write(String key, List<String> value) {
    _cache[key] = value;
    // Non attendu : la mesure ne doit jamais retarder l'interface. Une
    // écriture disque qui échoue est sans gravité — au pire un événement
    // unique repart une fois après réinstallation.
    unawaited(_prefs.setStringList(key, value).catchError((_) => false));
  }
}

/// Registre des événements à envoi unique, persistant entre les lancements.
///
/// Les clés sont bornées ([maxKeys], les plus anciennes sont oubliées) : un
/// client fidèle ne doit pas remplir le stockage de son téléphone avec
/// l'historique de ses paiements. Oublier une clé très ancienne est sans
/// conséquence — l'événement correspondant date de centaines de commandes.
class OnceRegistry {
  OnceRegistry(this._store, {this.maxKeys = 200});

  static const storageKey = 'lilia_analytics_once';

  final AnalyticsKeyStore _store;
  final int maxKeys;

  /// Réserve [key]. Rend `true` la première fois seulement.
  bool claim(String key) {
    final keys = List<String>.from(_store.read(storageKey) ?? const []);
    if (keys.contains(key)) return false;
    keys.add(key);
    _store.write(
      storageKey,
      keys.length > maxKeys ? keys.sublist(keys.length - maxKeys) : keys,
    );
    return true;
  }
}

/// Clés d'unicité métier.
///
/// Centralisées pour que le mobile et le web appliquent la même règle :
/// l'unicité porte sur l'**objet métier**, pas sur l'écran qui l'observe —
/// plusieurs écrans peuvent observer le même paiement, et c'est précisément ce
/// dont on se protège.
abstract final class AnalyticsOnceKey {
  static String orderCreated(String orderId) => 'order_created:$orderId';
  static String paymentStarted(String paymentId) => 'payment_started:$paymentId';
  static String paymentSuccess(String paymentId) => 'payment_success:$paymentId';
}
