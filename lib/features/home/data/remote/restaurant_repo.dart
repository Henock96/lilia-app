import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/restaurant.dart';

part 'restaurant_repo.g.dart';

class RestaurantRepository {
  /// Récupérer la liste de tous les restaurants (legacy /restaurants —
  /// backend filtre déjà sur adminApproved=true depuis Sprint B).
  Future<List<RestaurantSummary>> getAllRestaurants() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/restaurants'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)["data"];
        return data.map((json) => RestaurantSummary.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load restaurants: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// Marketplace multi-vendeurs (LIL-117) — GET /vendors avec filtre
  /// optionnel par VendorType. Backend filtre déjà sur isActive +
  /// adminApproved, on ne reçoit donc que les vendeurs visibles publiquement.
  /// Réponse paginée `{ data, meta }` — on garde uniquement `data`.
  Future<List<RestaurantSummary>> getVendors({VendorType? vendorType}) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/vendors').replace(
        queryParameters: {
          if (vendorType != null) 'vendorType': vendorType.name,
          'limit': '50',
        },
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)["data"];
        return data.map((json) => RestaurantSummary.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load vendors: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// Récupérer un restaurant par son ID avec ses produits
  Future<Restaurant> getRestaurant(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/restaurants/$id'),
      );

      if (response.statusCode == 200) {
        return Restaurant.fromJson(json.decode(response.body)["data"]);
      } else {
        throw Exception('Failed to load restaurant: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }
}

@Riverpod(keepAlive: true)
RestaurantRepository restaurantRepository(Ref ref) {
  return RestaurantRepository();
}
