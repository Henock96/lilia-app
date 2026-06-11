import 'package:flutter/foundation.dart';

/// Seuil (en caractères du body brut) au-delà duquel le parsing JSON est
/// déporté sur un isolate via [compute].
///
/// En dessous, le coût de spawn d'un isolate (+ copie du message) dépasse le
/// gain : on parse inline sur le main thread. Au-dessus (longues listes de
/// vendeurs / produits / commandes), `jsonDecode` + mapping peut bloquer
/// plusieurs frames → on l'isole pour garder l'UI fluide pendant le scroll.
const int kIsolateJsonThresholdChars = 40 * 1024; // ~40 KB

/// Exécute [parser] (décodage + mapping en modèles) sur [body].
///
/// Si [body] dépasse [kIsolateJsonThresholdChars], le travail part sur un
/// isolate (`compute`) ; sinon il s'exécute inline (évite la latence d'un
/// spawn d'isolate pour les petits payloads).
///
/// ⚠️ [parser] DOIT être une fonction **top-level ou statique** : c'est une
/// contrainte des isolates Dart (les closures capturant un contexte ne sont
/// pas transférables). Le résultat [R] doit être composé de types
/// transférables (modèles à champs primitifs : OK).
Future<R> parseJson<R>(String body, R Function(String) parser) {
  if (body.length < kIsolateJsonThresholdChars) {
    return Future<R>.value(parser(body));
  }
  return compute(parser, body);
}
