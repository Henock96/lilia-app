// lib/models/order_item.dart

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String variant;
  final int quantite;
  final double prix;
  final DateTime createdAt;
  final OrderItemProduct product; // Contient maintenant plus de détails sur le produit

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
      id: json['id'],
      orderId: json['orderId'],
      productId: json['productId'],
      variant: json['variant'],
      quantite: json['quantite'],
      prix: (json['prix'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      product: OrderItemProduct.fromJson(json['product']),
    );
  }
}

class OrderItemProduct {
  final String nom;
  final String description; // Nouvelle propriété
  final String? imageUrl;   // Nouvelle propriété (peut être null)

  OrderItemProduct({
    required this.nom,
    required this.description,
    this.imageUrl,
  });

  factory OrderItemProduct.fromJson(Map<String, dynamic> json) {
    return OrderItemProduct(
      nom: json['nom'],
      description: json['description'],
      imageUrl: json['imageUrl'], // Parsez la nouvelle propriété
    );
  }
}