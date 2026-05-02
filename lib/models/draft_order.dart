import 'dart:convert';

import 'package:lilia_app/models/cart.dart';

class DraftOrder {
  final String id;
  final String restaurantName;
  final List<CartItem> items;
  final double totalPrice;
  final DateTime createdAt;

  DraftOrder({
    required this.id,
    required this.restaurantName,
    required this.items,
    required this.totalPrice,
    required this.createdAt,
  });

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantite);

  Map<String, dynamic> toMap() => {
    'id': id,
    'restaurantName': restaurantName,
    'items': items.map((item) => item.toMap()).toList(),
    'totalPrice': totalPrice,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DraftOrder.fromMap(Map<String, dynamic> map) => DraftOrder(
    id: map['id'] as String,
    restaurantName: map['restaurantName'] as String,
    items: (map['items'] as List)
        .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
        .toList(),
    totalPrice: (map['totalPrice'] as num).toDouble(),
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  String toJson() => jsonEncode(toMap());

  factory DraftOrder.fromJson(String json) =>
      DraftOrder.fromMap(jsonDecode(json) as Map<String, dynamic>);
}
