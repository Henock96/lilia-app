// lib/models/order_item.dart

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

String _asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

int _asInt(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

double _asDouble(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

DateTime _asDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String variant;
  final int quantite;
  final double prix;
  final DateTime createdAt;
  final OrderItemProduct
  product; // Contient maintenant plus de détails sur le produit

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.variant,
    required this.quantite,
    required this.prix,
    required this.createdAt,
    required this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: _asString(json['id']),
      orderId: _asString(json['orderId']),
      productId: _asString(json['productId']),
      variant: _asString(json['variant'], 'Standard'),
      quantite: _asInt(json['quantite']),
      prix: _asDouble(json['prix']),
      createdAt: _asDate(json['createdAt']),
      product: OrderItemProduct.fromJson(_asMap(json['product'])),
    );
  }
}

class OrderItemProduct {
  final String nom;
  final String description; // Nouvelle propriété
  final String? imageUrl; // Nouvelle propriété (peut être null)

  OrderItemProduct({
    required this.nom,
    required this.description,
    this.imageUrl,
  });

  factory OrderItemProduct.fromJson(Map<String, dynamic> json) {
    return OrderItemProduct(
      nom: _asString(json['nom'], 'Produit'),
      description: _asString(json['description']),
      imageUrl: json['imageUrl'] is String ? json['imageUrl'] as String : null,
    );
  }
}
