// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider pour récupérer la liste de tous les restaurants

@ProviderFor(restaurantsList)
final restaurantsListProvider = RestaurantsListProvider._();

/// Provider pour récupérer la liste de tous les restaurants

final class RestaurantsListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RestaurantSummary>>,
          List<RestaurantSummary>,
          FutureOr<List<RestaurantSummary>>
        >
    with
        $FutureModifier<List<RestaurantSummary>>,
        $FutureProvider<List<RestaurantSummary>> {
  /// Provider pour récupérer la liste de tous les restaurants
  RestaurantsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restaurantsListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restaurantsListHash();

  @$internal
  @override
  $FutureProviderElement<List<RestaurantSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RestaurantSummary>> create(Ref ref) {
    return restaurantsList(ref);
  }
}

String _$restaurantsListHash() => r'9b773a68fec77399b25f969c5c0b6575210baf27';

/// **La carte d'un vendeur**, avec un cache borné.
///
/// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
///
/// | Geste | Effet |
/// |---|---|
/// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
/// | ouverture après `kMenuCacheTtl` | nouvel appel |
/// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
/// | tirer pour rafraîchir | nouvel appel, immédiat |
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.

@ProviderFor(restaurantController)
final restaurantControllerProvider = RestaurantControllerFamily._();

/// **La carte d'un vendeur**, avec un cache borné.
///
/// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
///
/// | Geste | Effet |
/// |---|---|
/// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
/// | ouverture après `kMenuCacheTtl` | nouvel appel |
/// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
/// | tirer pour rafraîchir | nouvel appel, immédiat |
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.

final class RestaurantControllerProvider
    extends
        $FunctionalProvider<
          AsyncValue<Restaurant>,
          Restaurant,
          FutureOr<Restaurant>
        >
    with $FutureModifier<Restaurant>, $FutureProvider<Restaurant> {
  /// **La carte d'un vendeur**, avec un cache borné.
  ///
  /// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
  ///
  /// | Geste | Effet |
  /// |---|---|
  /// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
  /// | ouverture après `kMenuCacheTtl` | nouvel appel |
  /// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
  /// | tirer pour rafraîchir | nouvel appel, immédiat |
  ///
  /// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
  /// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
  /// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
  /// quoi un provider détruit tôt laisserait un `Timer` en vol.
  RestaurantControllerProvider._({
    required RestaurantControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'restaurantControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$restaurantControllerHash();

  @override
  String toString() {
    return r'restaurantControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Restaurant> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Restaurant> create(Ref ref) {
    final argument = this.argument as String;
    return restaurantController(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$restaurantControllerHash() =>
    r'9a5004f49ea3bf85269ba4df2435d47e447add23';

/// **La carte d'un vendeur**, avec un cache borné.
///
/// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
///
/// | Geste | Effet |
/// |---|---|
/// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
/// | ouverture après `kMenuCacheTtl` | nouvel appel |
/// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
/// | tirer pour rafraîchir | nouvel appel, immédiat |
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.

final class RestaurantControllerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Restaurant>, String> {
  RestaurantControllerFamily._()
    : super(
        retry: null,
        name: r'restaurantControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// **La carte d'un vendeur**, avec un cache borné.
  ///
  /// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
  ///
  /// | Geste | Effet |
  /// |---|---|
  /// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
  /// | ouverture après `kMenuCacheTtl` | nouvel appel |
  /// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
  /// | tirer pour rafraîchir | nouvel appel, immédiat |
  ///
  /// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
  /// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
  /// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
  /// quoi un provider détruit tôt laisserait un `Timer` en vol.

  RestaurantControllerProvider call(String restaurantId) =>
      RestaurantControllerProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'restaurantControllerProvider';
}

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].

@ProviderFor(MarketplaceFilter)
final marketplaceFilterProvider = MarketplaceFilterProvider._();

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].
final class MarketplaceFilterProvider
    extends $NotifierProvider<MarketplaceFilter, VendorType?> {
  /// Filtre vendor type courant pour le marketplace (LIL-117).
  /// `null` = "Tous" (pas de filtre). Watched par [vendorsList].
  MarketplaceFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceFilterHash();

  @$internal
  @override
  MarketplaceFilter create() => MarketplaceFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VendorType? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VendorType?>(value),
    );
  }
}

String _$marketplaceFilterHash() => r'9de4b216d1b685124fca3e14dc2d727b34f1c92c';

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].

abstract class _$MarketplaceFilter extends $Notifier<VendorType?> {
  VendorType? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VendorType?, VendorType?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VendorType?, VendorType?>,
              VendorType?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Types de vendeurs présents au catalogue public, d'après la liste « Tous »
/// (lot G4, épiceries).
///
/// Une puce de filtre ne doit pas promettre une catégorie vide : « Épicerie »
/// apparaît le jour où la première épicerie est publiée, et pas avant. La
/// vérité vient de la liste que l'accueil charge déjà — aucune requête en
/// plus. Seule une liste NON filtrée est lue : une fois une puce choisie, la
/// liste filtrée ne dit plus rien des autres types, et le dernier ensemble
/// connu est conservé.
///
/// `null` tant qu'aucune liste « Tous » n'est arrivée : l'appelant garde alors
/// les puces historiques ([VendorType.marketplaceFilter]).
///
/// Limite : la liste « Tous » est bornée à 50 vendeurs ; un type présent
/// au-delà n'aurait pas de puce (il reste visible dans « Tous »).

@ProviderFor(MarketplaceVendorTypes)
final marketplaceVendorTypesProvider = MarketplaceVendorTypesProvider._();

/// Types de vendeurs présents au catalogue public, d'après la liste « Tous »
/// (lot G4, épiceries).
///
/// Une puce de filtre ne doit pas promettre une catégorie vide : « Épicerie »
/// apparaît le jour où la première épicerie est publiée, et pas avant. La
/// vérité vient de la liste que l'accueil charge déjà — aucune requête en
/// plus. Seule une liste NON filtrée est lue : une fois une puce choisie, la
/// liste filtrée ne dit plus rien des autres types, et le dernier ensemble
/// connu est conservé.
///
/// `null` tant qu'aucune liste « Tous » n'est arrivée : l'appelant garde alors
/// les puces historiques ([VendorType.marketplaceFilter]).
///
/// Limite : la liste « Tous » est bornée à 50 vendeurs ; un type présent
/// au-delà n'aurait pas de puce (il reste visible dans « Tous »).
final class MarketplaceVendorTypesProvider
    extends $NotifierProvider<MarketplaceVendorTypes, Set<VendorType>?> {
  /// Types de vendeurs présents au catalogue public, d'après la liste « Tous »
  /// (lot G4, épiceries).
  ///
  /// Une puce de filtre ne doit pas promettre une catégorie vide : « Épicerie »
  /// apparaît le jour où la première épicerie est publiée, et pas avant. La
  /// vérité vient de la liste que l'accueil charge déjà — aucune requête en
  /// plus. Seule une liste NON filtrée est lue : une fois une puce choisie, la
  /// liste filtrée ne dit plus rien des autres types, et le dernier ensemble
  /// connu est conservé.
  ///
  /// `null` tant qu'aucune liste « Tous » n'est arrivée : l'appelant garde alors
  /// les puces historiques ([VendorType.marketplaceFilter]).
  ///
  /// Limite : la liste « Tous » est bornée à 50 vendeurs ; un type présent
  /// au-delà n'aurait pas de puce (il reste visible dans « Tous »).
  MarketplaceVendorTypesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceVendorTypesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceVendorTypesHash();

  @$internal
  @override
  MarketplaceVendorTypes create() => MarketplaceVendorTypes();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<VendorType>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<VendorType>?>(value),
    );
  }
}

String _$marketplaceVendorTypesHash() =>
    r'1011ac32cd82ba7e5559bc79329394cd43f69f92';

/// Types de vendeurs présents au catalogue public, d'après la liste « Tous »
/// (lot G4, épiceries).
///
/// Une puce de filtre ne doit pas promettre une catégorie vide : « Épicerie »
/// apparaît le jour où la première épicerie est publiée, et pas avant. La
/// vérité vient de la liste que l'accueil charge déjà — aucune requête en
/// plus. Seule une liste NON filtrée est lue : une fois une puce choisie, la
/// liste filtrée ne dit plus rien des autres types, et le dernier ensemble
/// connu est conservé.
///
/// `null` tant qu'aucune liste « Tous » n'est arrivée : l'appelant garde alors
/// les puces historiques ([VendorType.marketplaceFilter]).
///
/// Limite : la liste « Tous » est bornée à 50 vendeurs ; un type présent
/// au-delà n'aurait pas de puce (il reste visible dans « Tous »).

abstract class _$MarketplaceVendorTypes extends $Notifier<Set<VendorType>?> {
  Set<VendorType>? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<VendorType>?, Set<VendorType>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<VendorType>?, Set<VendorType>?>,
              Set<VendorType>?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
/// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
/// Riverpod rebuilde et refetch automatiquement.

@ProviderFor(vendorsList)
final vendorsListProvider = VendorsListProvider._();

/// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
/// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
/// Riverpod rebuilde et refetch automatiquement.

final class VendorsListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RestaurantSummary>>,
          List<RestaurantSummary>,
          FutureOr<List<RestaurantSummary>>
        >
    with
        $FutureModifier<List<RestaurantSummary>>,
        $FutureProvider<List<RestaurantSummary>> {
  /// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
  /// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
  /// Riverpod rebuilde et refetch automatiquement.
  VendorsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vendorsListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vendorsListHash();

  @$internal
  @override
  $FutureProviderElement<List<RestaurantSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RestaurantSummary>> create(Ref ref) {
    return vendorsList(ref);
  }
}

String _$vendorsListHash() => r'aa8eca912df466772cc3a14e3290ac4168366bc7';
