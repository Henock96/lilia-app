import 'package:flutter/foundation.dart';

import 'analytics_dedupe.dart';
import 'analytics_sanitizer.dart';
import 'analytics_sink.dart';

/// Cœur de l'abstraction analytics — sans aucune dépendance à Firebase.
///
/// Le code métier n'appelle jamais `FirebaseAnalytics.instance`. Il passe par
/// `AnalyticsService` (la façade typée), qui passe par cette classe. Deux
/// raisons, dans cet ordre d'importance :
///
///  1. **Le contrat est appliqué à un seul endroit.** Désinfection, liste
///     blanche, déduplication : un appel qui contourne cette classe contourne
///     les trois. C'est pourquoi les écrans ne reçoivent jamais le SDK.
///  2. Changer d'outil de mesure devient un changement de collecteur, pas une
///     réécriture de vingt écrans.
class LiliaAnalytics {
  LiliaAnalytics({
    required List<AnalyticsSink> sinks,
    AnalyticsKeyStore? store,
    Duration repeatWindow = const Duration(seconds: 1),
    DateTime Function()? now,
  }) : _sinks = sinks,
       _guard = RepeatGuard(window: repeatWindow, now: now),
       _once = OnceRegistry(store ?? InMemoryKeyStore());

  final List<AnalyticsSink> _sinks;
  final RepeatGuard _guard;
  final OnceRegistry _once;
  static const _sanitizer = AnalyticsSanitizer();

  /// Envoie un événement du contrat.
  ///
  /// Ne lève jamais : un collecteur en erreur ne doit pas interrompre un
  /// paiement. Rend `true` si l'événement est parti — ce que les tests lisent.
  bool track(String event, [Map<String, Object?> params = const {}]) {
    final result = _sanitizer.sanitize(event, params);
    _warnDropped(event, result);
    if (!_guard.allow(analyticsSignature(event, result.params))) return false;
    _emit(event, result.params);
    return true;
  }

  /// Envoie un événement **au plus une fois pour [dedupeKey]**, définitivement.
  ///
  /// Réservé aux faits métier qui ne se produisent qu'une fois : une commande
  /// n'est créée qu'une fois, un paiement n'est confirmé qu'une fois. La clé
  /// doit donc porter l'identifiant du fait (`payment_success:<paymentId>`),
  /// pas celui de l'écran qui l'observe.
  bool trackOnce(
    String dedupeKey,
    String event, [
    Map<String, Object?> params = const {},
  ]) {
    if (!_once.claim(dedupeKey)) return false;
    final result = _sanitizer.sanitize(event, params);
    _warnDropped(event, result);
    _emit(event, result.params);
    return true;
  }

  /// Attache un identifiant interne aux envois suivants.
  ///
  /// ⚠️ **Jamais un numéro de téléphone, un e-mail ou un UID Firebase.** On
  /// passe l'identifiant applicatif (`AppUser.id`, le CUID de la base) : il est
  /// stable, il permet de recoller les parcours web et mobile du même client,
  /// et il ne désigne personne pour qui ne dispose pas déjà de la base.
  ///
  /// Un client déconnecté reste suivi — Firebase lui attribue un identifiant
  /// d'installation anonyme. Passer `null` **délie** le compte des envois
  /// suivants : sans cela, la session d'un visiteur anonyme sur un téléphone
  /// prêté resterait attribuée au compte précédent.
  void identify(String? userId) {
    for (final sink in _sinks) {
      try {
        sink.identify(userId);
      } catch (_) {
        // Silencieux par conception.
      }
    }
  }

  void _emit(String event, Map<String, Object> params) {
    for (final sink in _sinks) {
      try {
        sink.event(event, params);
      } catch (_) {
        // Un collecteur en panne n'en empêche pas un autre, et n'interrompt rien.
      }
    }
  }

  void _warnDropped(String event, SanitizeResult result) {
    if (!kDebugMode || result.dropped.isEmpty) return;
    debugPrint(
      '📊 [analytics] $event — paramètres retirés : '
      '${result.dropped.join(", ")}',
    );
  }
}
