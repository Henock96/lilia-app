import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/models/menu.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'menu_repo.g.dart';

class MenuRepository {
  /// Récupère tous les menus actifs
  /// Optionnellement filtré par restaurant
  Future<List<MenuDuJour>> getActiveMenus({String? restaurantId}) async {
    try {
      final uri = restaurantId != null
          ? Uri.parse(
              '${AppConstants.baseUrl}/menus/active?restaurantId=$restaurantId',
            )
          : Uri.parse('${AppConstants.baseUrl}/menus/active');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // /menus/active est double-enveloppé par l'interceptor backend
        // (`{ data: { message, data: [...], count } }`). On déballe l'enveloppe
        // externe puis on lit la liste — tolérant aux formes legacy.
        final menusJson = ApiResponse.listOf(ApiResponse.mapOf(decoded));
        return menusJson.map((json) => MenuDuJour.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load menus: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// Récupère un menu spécifique par son ID
  Future<MenuDuJour> getMenuById(String menuId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/menus/$menuId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MenuDuJour.fromJson(data['data']);
      } else {
        throw Exception('Failed to load menu: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// Récupère tous les menus (actifs et inactifs)
  /// Avec filtres optionnels
  Future<List<MenuDuJour>> getAllMenus({
    String? restaurantId,
    bool? isActive,
    bool includeExpired = false,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (restaurantId != null) queryParams['restaurantId'] = restaurantId;
      if (isActive != null) queryParams['isActive'] = isActive.toString();
      if (includeExpired) queryParams['includeExpired'] = 'true';

      final uri = Uri.parse(
        '${AppConstants.baseUrl}/menus',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Idem `getActiveMenus` : `/menus` est double-enveloppé (contient `count`).
        final menusJson = ApiResponse.listOf(ApiResponse.mapOf(decoded));
        return menusJson.map((json) => MenuDuJour.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load menus: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }
}

@Riverpod(keepAlive: true)
MenuRepository menuRepository(Ref ref) {
  return MenuRepository();
}
