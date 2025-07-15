import 'dart:convert';

import 'package:lilia_app/models/restaurant.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/produit.dart';

part 'favorites_provider.g.dart';

const _kFavoritesKey = 'favorites';

@riverpod
class Favorites extends _$Favorites {
  late SharedPreferences _prefs;

  @override
  Future<List<Product>> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _getFavorites();
  }

  List<Product> _getFavorites() {
    final favoritesJson = _prefs.getStringList(_kFavoritesKey) ?? [];
    return favoritesJson
        .map((jsonString) => Product.fromJson(jsonDecode(jsonString)))
        .toList();
  }

  Future<void> _setFavorites(List<Product> products) async {
    final favoritesJson = products
        .map((product) => jsonEncode(product.toJson()))
        .toList();
    await _prefs.setStringList(_kFavoritesKey, favoritesJson);
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
    final updatedFavorites =
        currentFavorites.where((p) => p.id != product.id).toList();
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
      'restaurantId': restaurantId,
      'categoryId': categoryId,
      'category': category?.toJson(),
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}

extension CategoryJson on Category {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': name,
    };
  }
}

extension ProductVariantJson on ProductVariant {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'prix': prix,
    };
  }
}