import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';

class SearchResult {
  final List<RestaurantSummary> restaurants;
  final List<Product> products;

  SearchResult({required this.restaurants, required this.products});

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      restaurants:
          (json['restaurants'] as List?)
              ?.map(
                (r) => RestaurantSummary.fromJson(r as Map<String, dynamic>),
              )
              .toList() ??
          [],
      products:
          (json['products'] as List?)
              ?.map((p) => Product.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isEmpty => restaurants.isEmpty && products.isEmpty;
}
