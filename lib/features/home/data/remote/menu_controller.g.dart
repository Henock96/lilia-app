// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider pour récupérer les menus actifs d'un restaurant

@ProviderFor(activeMenus)
final activeMenusProvider = ActiveMenusFamily._();

/// Provider pour récupérer les menus actifs d'un restaurant

final class ActiveMenusProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MenuDuJour>>,
          List<MenuDuJour>,
          FutureOr<List<MenuDuJour>>
        >
    with $FutureModifier<List<MenuDuJour>>, $FutureProvider<List<MenuDuJour>> {
  /// Provider pour récupérer les menus actifs d'un restaurant
  ActiveMenusProvider._({
    required ActiveMenusFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'activeMenusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeMenusHash();

  @override
  String toString() {
    return r'activeMenusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MenuDuJour>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MenuDuJour>> create(Ref ref) {
    final argument = this.argument as String?;
    return activeMenus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveMenusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeMenusHash() => r'adc1a47bc7f6fb026bb0eeffb20eeb9ff1d6998a';

/// Provider pour récupérer les menus actifs d'un restaurant

final class ActiveMenusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MenuDuJour>>, String?> {
  ActiveMenusFamily._()
    : super(
        retry: null,
        name: r'activeMenusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour récupérer les menus actifs d'un restaurant

  ActiveMenusProvider call(String? restaurantId) =>
      ActiveMenusProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'activeMenusProvider';
}

/// Provider pour récupérer un menu spécifique par son ID

@ProviderFor(menuDetails)
final menuDetailsProvider = MenuDetailsFamily._();

/// Provider pour récupérer un menu spécifique par son ID

final class MenuDetailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MenuDuJour>,
          MenuDuJour,
          FutureOr<MenuDuJour>
        >
    with $FutureModifier<MenuDuJour>, $FutureProvider<MenuDuJour> {
  /// Provider pour récupérer un menu spécifique par son ID
  MenuDetailsProvider._({
    required MenuDetailsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'menuDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$menuDetailsHash();

  @override
  String toString() {
    return r'menuDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MenuDuJour> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MenuDuJour> create(Ref ref) {
    final argument = this.argument as String;
    return menuDetails(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MenuDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$menuDetailsHash() => r'8707783b402840a6da09b7f06fc85c2a8eba7ed4';

/// Provider pour récupérer un menu spécifique par son ID

final class MenuDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MenuDuJour>, String> {
  MenuDetailsFamily._()
    : super(
        retry: null,
        name: r'menuDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour récupérer un menu spécifique par son ID

  MenuDetailsProvider call(String menuId) =>
      MenuDetailsProvider._(argument: menuId, from: this);

  @override
  String toString() => r'menuDetailsProvider';
}

/// Provider pour récupérer tous les menus (avec filtres)

@ProviderFor(allMenus)
final allMenusProvider = AllMenusFamily._();

/// Provider pour récupérer tous les menus (avec filtres)

final class AllMenusProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MenuDuJour>>,
          List<MenuDuJour>,
          FutureOr<List<MenuDuJour>>
        >
    with $FutureModifier<List<MenuDuJour>>, $FutureProvider<List<MenuDuJour>> {
  /// Provider pour récupérer tous les menus (avec filtres)
  AllMenusProvider._({
    required AllMenusFamily super.from,
    required ({String? restaurantId, bool? isActive, bool includeExpired})
    super.argument,
  }) : super(
         retry: null,
         name: r'allMenusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$allMenusHash();

  @override
  String toString() {
    return r'allMenusProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<MenuDuJour>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MenuDuJour>> create(Ref ref) {
    final argument =
        this.argument
            as ({String? restaurantId, bool? isActive, bool includeExpired});
    return allMenus(
      ref,
      restaurantId: argument.restaurantId,
      isActive: argument.isActive,
      includeExpired: argument.includeExpired,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AllMenusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$allMenusHash() => r'8ea2663d36f52b471599909d2e9cf7e8fbe3c114';

/// Provider pour récupérer tous les menus (avec filtres)

final class AllMenusFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MenuDuJour>>,
          ({String? restaurantId, bool? isActive, bool includeExpired})
        > {
  AllMenusFamily._()
    : super(
        retry: null,
        name: r'allMenusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour récupérer tous les menus (avec filtres)

  AllMenusProvider call({
    String? restaurantId,
    bool? isActive,
    bool includeExpired = false,
  }) => AllMenusProvider._(
    argument: (
      restaurantId: restaurantId,
      isActive: isActive,
      includeExpired: includeExpired,
    ),
    from: this,
  );

  @override
  String toString() => r'allMenusProvider';
}
