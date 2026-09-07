import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/models/menu.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'menu_repo.g.dart';

class MenuRepository {
  final ApiClient _api;

  MenuRepository(this._api);

  /// Récupère tous les menus actifs
  /// Optionnellement filtré par restaurant
  Future<List<MenuDuJour>> getActiveMenus({String? restaurantId}) async {
    final res = await _api.getJson(
      '/menus/active',
      query: {'restaurantId': ?restaurantId},
    );
    // /menus/active est double-enveloppé par l'interceptor backend
    // (`{ data: { message, data: [...], count } }`). On déballe l'enveloppe
    // externe puis on lit la liste — tolérant aux formes legacy.
    final menusJson = ApiResponse.listOf(ApiResponse.mapOf(res.data));
    return menusJson
        .map((json) => MenuDuJour.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Récupère un menu spécifique par son ID
  Future<MenuDuJour> getMenuById(String menuId) async {
    final res = await _api.getJson('/menus/$menuId');
    return MenuDuJour.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Récupère tous les menus (actifs et inactifs)
  /// Avec filtres optionnels
  Future<List<MenuDuJour>> getAllMenus({
    String? restaurantId,
    bool? isActive,
    bool includeExpired = false,
  }) async {
    final queryParams = <String, dynamic>{};
    if (restaurantId != null) queryParams['restaurantId'] = restaurantId;
    if (isActive != null) queryParams['isActive'] = isActive.toString();
    if (includeExpired) queryParams['includeExpired'] = 'true';

    final res = await _api.getJson('/menus', query: queryParams);
    // Idem `getActiveMenus` : `/menus` est double-enveloppé (contient `count`).
    final menusJson = ApiResponse.listOf(ApiResponse.mapOf(res.data));
    return menusJson
        .map((json) => MenuDuJour.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
MenuRepository menuRepository(Ref ref) {
  return MenuRepository(ref.watch(apiClientProvider));
}
