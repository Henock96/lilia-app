import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/restaurant.dart';


part 'restaurant_repo.g.dart';

class RestaurantRepository {
  final String _baseUrl = 'https://lilia-backend.onrender.com'; // Assurez-vous que votre backend est en cours d'exécution sur ce port

  Future<Restaurant> getRestaurant(String id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/restaurants/$id'));

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
RestaurantRepository restaurantRepository(RestaurantRepositoryRef ref) {
  return RestaurantRepository();
}