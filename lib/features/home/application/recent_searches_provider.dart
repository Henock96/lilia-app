import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';
import '../../auth/repository/firebase_auth_repository.dart';

part 'recent_searches_provider.g.dart';

const _kRecentSearchesKey = 'recent_searches';

/// Nombre de recherches récentes conservées.
const int kRecentSearchesMax = 8;

/// **Recherches récentes**, sur cet appareil et pour ce compte seulement.
///
/// Le texte saisi est un contenu libre : il contient parfois un nom ou un
/// numéro. Il ne quitte donc jamais le téléphone (le contrat analytics
/// interdit de l'envoyer), il est rangé par compte (`cleParCompte`) comme les
/// favoris — un changement de compte ne montre pas l'historique du précédent —
/// et le client peut l'effacer d'un geste.
@riverpod
class RecentSearches extends _$RecentSearches {
  late SharedPreferences _prefs;
  late String _cle;

  @override
  Future<List<String>> build() async {
    _prefs = await SharedPreferences.getInstance();
    _cle = cleParCompte(
      _kRecentSearchesKey,
      ref.watch(authRepositoryProvider).currentUser?.uid,
    );
    return _prefs.getStringList(_cle) ?? const [];
  }

  /// Ajoute [query] en tête ; un doublon (casse ignorée) remonte au lieu de
  /// se répéter.
  Future<void> add(String query) async {
    final q = query.trim();
    if (q.length < kSearchMinLength) return;
    final current = await future;
    final next = [
      q,
      ...current.where((e) => e.toLowerCase() != q.toLowerCase()),
    ].take(kRecentSearchesMax).toList();
    await _save(next);
  }

  Future<void> remove(String query) async {
    final current = await future;
    await _save(current.where((e) => e != query).toList());
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> values) async {
    await _prefs.setStringList(_cle, values);
    state = AsyncData(values);
  }
}

/// Longueur minimale d'une recherche envoyée au serveur.
///
/// Une seule lettre (« a ») rend presque tout le catalogue, sans ordre utile :
/// c'est du bruit pour le client et une requête lourde pour le serveur.
const int kSearchMinLength = 2;
