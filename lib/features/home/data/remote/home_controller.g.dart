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

String _$popularProductsHash() => r'80528c80bd838d7eab7ad9c40ca8731e447c1d41';

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

/// **Un produit, par son identifiant.**
///
/// Existe pour que `/product/:productId` soit une adresse complète : la fiche
/// se rendait uniquement depuis un `Product` passé en `extra` de navigation,
/// et `extra` ne survit pas à une mort de processus. Le client qui revenait
/// dans l'application après un appel téléphonique tombait sur « page
/// introuvable ».
///
/// Mis en cache comme les listes du catalogue : revenir sur une fiche déjà
/// vue ne coûte rien pendant cinq minutes, et au-delà les prix et la
/// disponibilité sont redemandés.

@ProviderFor(productById)
final productByIdProvider = ProductByIdFamily._();

/// **Un produit, par son identifiant.**
///
/// Existe pour que `/product/:productId` soit une adresse complète : la fiche
/// se rendait uniquement depuis un `Product` passé en `extra` de navigation,
/// et `extra` ne survit pas à une mort de processus. Le client qui revenait
/// dans l'application après un appel téléphonique tombait sur « page
/// introuvable ».
///
/// Mis en cache comme les listes du catalogue : revenir sur une fiche déjà
/// vue ne coûte rien pendant cinq minutes, et au-delà les prix et la
/// disponibilité sont redemandés.

final class ProductByIdProvider
    extends $FunctionalProvider<AsyncValue<Product>, Product, FutureOr<Product>>
    with $FutureModifier<Product>, $FutureProvider<Product> {
  /// **Un produit, par son identifiant.**
  ///
  /// Existe pour que `/product/:productId` soit une adresse complète : la fiche
  /// se rendait uniquement depuis un `Product` passé en `extra` de navigation,
  /// et `extra` ne survit pas à une mort de processus. Le client qui revenait
  /// dans l'application après un appel téléphonique tombait sur « page
  /// introuvable ».
  ///
  /// Mis en cache comme les listes du catalogue : revenir sur une fiche déjà
  /// vue ne coûte rien pendant cinq minutes, et au-delà les prix et la
  /// disponibilité sont redemandés.
  ProductByIdProvider._({
    required ProductByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'productByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$productByIdHash();

  @override
  String toString() {
    return r'productByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Product> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Product> create(Ref ref) {
    final argument = this.argument as String;
    return productById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productByIdHash() => r'9adfeed90fed765a906db6a0cb1afd61773b2985';

/// **Un produit, par son identifiant.**
///
/// Existe pour que `/product/:productId` soit une adresse complète : la fiche
/// se rendait uniquement depuis un `Product` passé en `extra` de navigation,
/// et `extra` ne survit pas à une mort de processus. Le client qui revenait
/// dans l'application après un appel téléphonique tombait sur « page
/// introuvable ».
///
/// Mis en cache comme les listes du catalogue : revenir sur une fiche déjà
/// vue ne coûte rien pendant cinq minutes, et au-delà les prix et la
/// disponibilité sont redemandés.

final class ProductByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Product>, String> {
  ProductByIdFamily._()
    : super(
        retry: null,
        name: r'productByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// **Un produit, par son identifiant.**
  ///
  /// Existe pour que `/product/:productId` soit une adresse complète : la fiche
  /// se rendait uniquement depuis un `Product` passé en `extra` de navigation,
  /// et `extra` ne survit pas à une mort de processus. Le client qui revenait
  /// dans l'application après un appel téléphonique tombait sur « page
  /// introuvable ».
  ///
  /// Mis en cache comme les listes du catalogue : revenir sur une fiche déjà
  /// vue ne coûte rien pendant cinq minutes, et au-delà les prix et la
  /// disponibilité sont redemandés.

  ProductByIdProvider call(String productId) =>
      ProductByIdProvider._(argument: productId, from: this);

  @override
  String toString() => r'productByIdProvider';
}
