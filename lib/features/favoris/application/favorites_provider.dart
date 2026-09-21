import 'dart:convert';

import 'package:lilia_app/models/restaurant.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';
import '../../auth/repository/firebase_auth_repository.dart';

import '../../../models/produit.dart';

part 'favorites_provider.g.dart';

const _kFavoritesKey = 'favorites';

@riverpod
class Favorites extends _$Favorites {
  late SharedPreferences _prefs;

  /// Clé du compte connecté — `favorites__<uid>`, ou `favorites__invite`.
  ///
  /// Résolue à chaque `build`, jamais retenue : le provider est invalidé à la
  /// déconnexion et au changement de compte
  /// (`invalidateUserScopedProviders`), donc il relit la bonne.
  late String _cle;

  @override
  Future<List<Product>> build() async {
    _prefs = await SharedPreferences.getInstance();
    _cle = cleParCompte(
      _kFavoritesKey,
      ref.watch(authRepositoryProvider).currentUser?.uid,
    );
    return _getFavorites();
  }

  List<Product> _getFavorites() {
    final favoritesJson = _prefs.getStringList(_cle) ?? [];
    return favoritesJson
        .map(
          (jsonString) =>
              Product.fromJson(jsonDecode(jsonString) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _setFavorites(List<Product> products) async {
    final favoritesJson = products
        .map((product) => jsonEncode(product.toJson()))
        .toList();
    await _prefs.setStringList(_cle, favoritesJson);
    state = AsyncData(products);
  }

  Future<void> add(Product product) async {
    final currentFavorites = await future;
    if (!currentFavorites.any((p) => p.id == product.id)) {
      final updatedFavorites = [...currentFavorites, product];
      await _setFavorites(updatedFavorites);
    }
  }

  Future<void> remove(Product product) async {
    final currentFavorites = await future;
    final updatedFavorites = currentFavorites
        .where((p) => p.id != product.id)
        .toList();
    await _setFavorites(updatedFavorites);
  }

  Future<bool> isFavorite(Product product) async {
    final currentFavorites = await future;
    return currentFavorites.any((p) => p.id == product.id);
  }
}

extension ProductJson on Product {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': name,
      'description': description,
      'prixOriginal': prixOriginal,
      'imageUrl': imageUrl,
      'images': images.map((i) => i.toJson()).toList(),
      'restaurantId': restaurantId,
      'categoryId': categoryId,
      'category': category?.toJson(),
      'variants': variants.map((v) => v.toJson()).toList(),
      'stockRestant': stockRestant,
      'orderCount': orderCount,
      if (restaurantName != null)
        'restaurant': {
          'nom': restaurantName,
          'imageUrl': restaurantImageUrl,
          'isOpen': restaurantIsOpen,
        },
    };
  }
}

extension CategoryJson on Category {
  Map<String, dynamic> toJson() {
    return {'id': id, 'nom': name};
  }
}

extension ProductVariantJson on ProductVariant {
  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'prix': prix};
  }
}
