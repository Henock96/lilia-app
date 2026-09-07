import 'analytics_events.dart';

/// Désinfection des paramètres avant envoi.
///
/// Trois passes, dans cet ordre, et l'ordre compte :
///
///  1. **Liste blanche** — seuls les paramètres déclarés dans
///     `analyticsEventParams` survivent. C'est ce qui empêche un modèle
///     `Product` ou `Order` entier de partir chez Google parce qu'on l'a passé
///     par commodité.
///  2. **Fragments de clés interdits** — second filet, volontairement redondant
///     avec le premier : il protège des ajouts futurs à la liste blanche.
///  3. **Formes de valeurs** — un numéro de téléphone reste un numéro de
///     téléphone même rangé sous une clé nommée `reference`.
///
/// Rien ici ne lève : une erreur de mesure ne doit jamais casser un parcours
/// d'achat.
class AnalyticsSanitizer {
  const AnalyticsSanitizer();

  /// Applique le contrat à une charge utile brute.
  ///
  /// Un événement inconnu ne laisse rien passer : mieux vaut un événement sans
  /// paramètre qu'un événement avec des paramètres non contractuels.
  SanitizeResult sanitize(String event, Map<String, Object?> raw) {
    final allowed = analyticsEventParams[event] ?? const <String>[];
    final params = <String, Object>{};
    final dropped = <DroppedParam>[];

    raw.forEach((key, value) {
      if (value == null) {
        dropped.add(DroppedParam(key, DropReason.empty));
        return;
      }
      if (!allowed.contains(key)) {
        dropped.add(DroppedParam(key, DropReason.notInContract));
        return;
      }
      if (isForbiddenKey(key)) {
        dropped.add(DroppedParam(key, DropReason.forbiddenKey));
        return;
      }

      final coerced = _coerce(value);
      if (coerced == null) {
        dropped.add(DroppedParam(key, DropReason.unsupportedType));
        return;
      }
      if (looksLikePii(coerced)) {
        dropped.add(DroppedParam(key, DropReason.piiValue));
        return;
      }

      params[key] = coerced is String
          ? (coerced.length > analyticsMaxStringLength
                ? coerced.substring(0, analyticsMaxStringLength)
                : coerced)
          : coerced;
    });

    return SanitizeResult(params, dropped);
  }

  /// Une clé porte-t-elle un fragment interdit ?
  ///
  /// La comparaison se fait **par segment**, pas par sous-chaîne : sans cela,
  /// `cart_total` contiendrait `tel` et tout montant serait rejeté. Le découpage
  /// traite aussi la casse chameau — le code Dart du projet mélange les deux
  /// conventions, et `deliveryLatitude` doit être reconnu comme
  /// `delivery_latitude`.
  static bool isForbiddenKey(String key) {
    final segments = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((s) => s.isNotEmpty);
    return segments.any(forbiddenParamFragments.contains);
  }

  /// La valeur ressemble-t-elle à une donnée personnelle ?
  static bool looksLikePii(Object value) {
    if (value is! String) return false;
    return analyticsPiiPatterns.any((p) => p.hasMatch(value));
  }

  /// Ramène une valeur à l'un des types transmissibles par Firebase Analytics.
  ///
  /// Les objets et collections sont rejetés plutôt qu'aplatis : un objet aplati,
  /// ce sont des clés qu'aucune liste blanche n'a validées. Les booléens sont
  /// rendus en texte — le SDK n'accepte que `String` et `num`.
  static Object? _coerce(Object value) {
    if (value is String) return value.trim().isEmpty ? null : value;
    if (value is bool) return value.toString();
    if (value is num) {
      // NaN et l'infini produisent des agrégats faux et silencieux.
      return value.isFinite ? value : null;
    }
    return null;
  }
}

enum DropReason {
  notInContract,
  forbiddenKey,
  piiValue,
  unsupportedType,
  empty,
}

class DroppedParam {
  const DroppedParam(this.key, this.reason);
  final String key;
  final DropReason reason;

  @override
  String toString() => '$key (${reason.name})';
}

class SanitizeResult {
  const SanitizeResult(this.params, this.dropped);

  /// Paramètres prêts à partir.
  final Map<String, Object> params;

  /// Clés retirées, avec le motif — exploité par les tests et les journaux.
  final List<DroppedParam> dropped;
}
