// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Favorites)
final favoritesProvider = FavoritesProvider._();

final class FavoritesProvider
    extends $AsyncNotifierProvider<Favorites, List<Product>> {
  FavoritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesHash();

  @$internal
  @override
  Favorites create() => Favorites();
}

String _$favoritesHash() => r'0c2516cdea933097658f6f087c5a969b89314100';

abstract class _$Favorites extends $AsyncNotifier<List<Product>> {
  FutureOr<List<Product>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Product>>, List<Product>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Product>>, List<Product>>,
              AsyncValue<List<Product>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
