import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rendu d'un `AsyncValue` qui **ne cache pas une panne derrière un
/// chargement**.
///
/// Riverpod 3 relance tout seul un provider en erreur (10 essais, de 200 ms à
/// 6,4 s — environ 38 s cumulées). Pendant ces relances l'état est un
/// `AsyncLoading` qui porte l'erreur, et `when` le range dans `loading` :
/// l'écran montrait un shimmer ou un spinner pendant ~38 s, puis seulement le
/// message et son bouton « Réessayer ». Sur la 4G de Brazzaville, personne
/// n'attend 38 s.
///
/// Ici, une erreur connue l'emporte sur le chargement. Le chargement initial
/// et le changement de filtre (sans erreur) restent des chargements.
///
/// Même règle que `ResolutionParIdentifiant` (`isLoading && !hasError`).
extension AsyncValueUi<T> on AsyncValue<T> {
  R whenUi<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) {
    if (isLoading && hasError && !hasValue) {
      return error(this.error!, stackTrace!);
    }
    return when(data: data, error: error, loading: loading);
  }
}
