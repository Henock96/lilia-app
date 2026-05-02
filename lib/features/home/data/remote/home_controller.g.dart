// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider pour les plats populaires

@ProviderFor(popularProducts)
final popularProductsProvider = PopularProductsProvider._();

/// Provider pour les plats populaires

final class PopularProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  /// Provider pour les plats populaires
  PopularProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return popularProducts(ref);
  }
}

String _$popularProductsHash() => r'fbbca65b75d6b8a3bdea9e021a8a9622bfaafd3f';

/// Provider pour les restaurants populaires

@ProviderFor(popularRestaurants)
final popularRestaurantsProvider = PopularRestaurantsProvider._();

/// Provider pour les restaurants populaires

final class PopularRestaurantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RestaurantSummary>>,
          List<RestaurantSummary>,
          FutureOr<List<RestaurantSummary>>
        >
    with
        $FutureModifier<List<RestaurantSummary>>,
        $FutureProvider<List<RestaurantSummary>> {
  /// Provider pour les restaurants populaires
  PopularRestaurantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularRestaurantsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularRestaurantsHash();

  @$internal
  @override
  $FutureProviderElement<List<RestaurantSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RestaurantSummary>> create(Ref ref) {
    return popularRestaurants(ref);
  }
}

String _$popularRestaurantsHash() =>
    r'2e8c4470c262675c71feb9a2317d0a699696c88f';

/// Provider pour les recommandations (basées sur l'historique utilisateur)

@ProviderFor(recommendations)
final recommendationsProvider = RecommendationsProvider._();

/// Provider pour les recommandations (basées sur l'historique utilisateur)

final class RecommendationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  /// Provider pour les recommandations (basées sur l'historique utilisateur)
  RecommendationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recommendationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recommendationsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return recommendations(ref);
  }
}

String _$recommendationsHash() => r'993cbc5d9cd55ab11279ba9e4121058622fee06d';

/// Provider pour la liste des catégories

@ProviderFor(categoriesList)
final categoriesListProvider = CategoriesListProvider._();

/// Provider pour la liste des catégories

final class CategoriesListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          List<Category>,
          FutureOr<List<Category>>
        >
    with $FutureModifier<List<Category>>, $FutureProvider<List<Category>> {
  /// Provider pour la liste des catégories
  CategoriesListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesListHash();

  @$internal
  @override
  $FutureProviderElement<List<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Category>> create(Ref ref) {
    return categoriesList(ref);
  }
}

String _$categoriesListHash() => r'77b983d17dbdd6e7bc7aaa721ce2972ceecc4f8c';

/// Provider pour les résultats de recherche

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// Provider pour les résultats de recherche

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchResult>,
          SearchResult,
          FutureOr<SearchResult>
        >
    with $FutureModifier<SearchResult>, $FutureProvider<SearchResult> {
  /// Provider pour les résultats de recherche
  SearchResultsProvider._({
    required SearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @override
  String toString() {
    return r'searchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SearchResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SearchResult> create(Ref ref) {
    final argument = this.argument as String;
    return searchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultsHash() => r'9f7d538856592ac770bcfc3318f126f70d3fe764';

/// Provider pour les résultats de recherche

final class SearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SearchResult>, String> {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour les résultats de recherche

  SearchResultsProvider call(String query) =>
      SearchResultsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchResultsProvider';
}
