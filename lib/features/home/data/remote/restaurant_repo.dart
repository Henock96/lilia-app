import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/restaurant.dart';

part 'restaurant_repo.g.dart';

class RestaurantRepository {
  /// Récupérer la liste de tous les restaurants
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

  /// Récupérer un restaurant par son ID avec ses produits
  Future<Restaurant> getRestaurant(String id) async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/restaurants/$id'));

      if (response.statusCode == 200) {
        return Restaurant.fromJson(json.decode(response.body));
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
