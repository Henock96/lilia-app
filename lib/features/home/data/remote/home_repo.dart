import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../constants/app_constants.dart';
import '../../../../models/produit.dart';
import '../../../../models/restaurant.dart';
import '../../../../models/search_result.dart';

part 'home_repo.g.dart';

class HomeRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _firebaseAuth.currentUser;
    return await user?.getIdToken();
  }

  /// GET /products/popular?limit=10
  Future<List<Product>> getPopularProducts({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/products/popular?limit=$limit'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        return data.map((j) => Product.fromJson(j)).toList();
      }
      throw Exception('Failed to load popular products: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// GET /restaurants/popular?limit=6
  Future<List<RestaurantSummary>> getPopularRestaurants({int limit = 6}) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/restaurants/popular?limit=$limit'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        return data.map((j) => RestaurantSummary.fromJson(j)).toList();
      }
      throw Exception('Failed to load popular restaurants: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// GET /products/search?q=...
  Future<SearchResult> search(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/products/search?q=${Uri.encodeComponent(query)}',
        ),
      );
      if (response.statusCode == 200) {
        return SearchResult.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to search: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  /// GET /products/recommendations (authentifié)
  Future<List<Product>> getRecommendations({int limit = 10}) async {
    try {
      final token = await _getIdToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/products/recommendations?limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        return data.map((j) => Product.fromJson(j)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/categories'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        return data.map((j) => Category.fromJson(j)).toList();
      }
      throw Exception('Failed to load categories: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }
}

@Riverpod(keepAlive: true)
HomeRepository homeRepository(Ref ref) {
  return HomeRepository();
}
