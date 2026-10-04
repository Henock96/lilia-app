// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_searches_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// **Recherches récentes**, sur cet appareil et pour ce compte seulement.
///
/// Le texte saisi est un contenu libre : il contient parfois un nom ou un
/// numéro. Il ne quitte donc jamais le téléphone (le contrat analytics
/// interdit de l'envoyer), il est rangé par compte (`cleParCompte`) comme les
/// favoris — un changement de compte ne montre pas l'historique du précédent —
/// et le client peut l'effacer d'un geste.

@ProviderFor(RecentSearches)
final recentSearchesProvider = RecentSearchesProvider._();

/// **Recherches récentes**, sur cet appareil et pour ce compte seulement.
///
/// Le texte saisi est un contenu libre : il contient parfois un nom ou un
/// numéro. Il ne quitte donc jamais le téléphone (le contrat analytics
/// interdit de l'envoyer), il est rangé par compte (`cleParCompte`) comme les
/// favoris — un changement de compte ne montre pas l'historique du précédent —
/// et le client peut l'effacer d'un geste.
final class RecentSearchesProvider
    extends $AsyncNotifierProvider<RecentSearches, List<String>> {
  /// **Recherches récentes**, sur cet appareil et pour ce compte seulement.
  ///
  /// Le texte saisi est un contenu libre : il contient parfois un nom ou un
  /// numéro. Il ne quitte donc jamais le téléphone (le contrat analytics
  /// interdit de l'envoyer), il est rangé par compte (`cleParCompte`) comme les
  /// favoris — un changement de compte ne montre pas l'historique du précédent —
  /// et le client peut l'effacer d'un geste.
  RecentSearchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentSearchesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentSearchesHash();

  @$internal
  @override
  RecentSearches create() => RecentSearches();
}

String _$recentSearchesHash() => r'8a1cf5e64ff802c028ba44153964f0973b53dc10';

/// **Recherches récentes**, sur cet appareil et pour ce compte seulement.
///
/// Le texte saisi est un contenu libre : il contient parfois un nom ou un
/// numéro. Il ne quitte donc jamais le téléphone (le contrat analytics
/// interdit de l'envoyer), il est rangé par compte (`cleParCompte`) comme les
/// favoris — un changement de compte ne montre pas l'historique du précédent —
/// et le client peut l'effacer d'un geste.

abstract class _$RecentSearches extends $AsyncNotifier<List<String>> {
  FutureOr<List<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<String>>, List<String>>,
              AsyncValue<List<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
