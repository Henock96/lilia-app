import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Une destination de mesure. Le cœur n'en connaît aucune en particulier.
abstract interface class AnalyticsSink {
  String get name;
  void event(String name, Map<String, Object> params);

  /// Associe les envois suivants à un identifiant interne, ou les délie.
  void identify(String? userId);
}

/// Firebase Analytics — le collecteur de production, sur Android comme sur iOS.
///
/// Le SDK n'accepte que `String` et `num` en valeur de paramètre ; la
/// conversion est déjà faite par le désinfecteur, ce collecteur ne fait que
/// transmettre.
///
/// Les appels ne sont pas attendus : la mesure ne doit jamais retarder une
/// interface, et le SDK met déjà les envois en file lui-même.
class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalyticsSink(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  String get name => 'firebase';

  @override
  void event(String name, Map<String, Object> params) {
    _analytics.logEvent(name: name, parameters: params).catchError((_) {});
  }

  @override
  void identify(String? userId) {
    _analytics.setUserId(id: userId).catchError((_) {});
  }
}

/// Collecteur de développement.
///
/// Affiche ce qui *serait* envoyé. C'est le seul moyen de vérifier une
/// instrumentation sur un émulateur sans attendre le délai de propagation de la
/// console Firebase, et sans polluer les statistiques de production.
class DebugAnalyticsSink implements AnalyticsSink {
  const DebugAnalyticsSink();

  @override
  String get name => 'debug';

  @override
  void event(String name, Map<String, Object> params) {
    debugPrint('📊 [analytics] $name $params');
  }

  @override
  void identify(String? userId) {
    debugPrint('📊 [analytics] identify ${userId ?? "(anonyme)"}');
  }
}

/// Collecteur d'essai — enregistre au lieu d'envoyer. Utilisé par les tests.
class RecordingAnalyticsSink implements AnalyticsSink {
  final List<({String name, Map<String, Object> params})> events = [];
  final List<String?> identified = [];

  @override
  String get name => 'recording';

  @override
  void event(String name, Map<String, Object> params) {
    events.add((name: name, params: params));
  }

  @override
  void identify(String? userId) => identified.add(userId);

  List<String> get names => events.map((e) => e.name).toList();
}
