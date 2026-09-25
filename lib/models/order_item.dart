// lib/models/order_item.dart

import 'package:lilia_app/models/modifier.dart';

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
  /// Prix unitaire figé — **options comprises** depuis F3-09 (décision Q1) :
  /// `prix × quantite` reste le montant de la ligne, sans rien additionner.
  final double prix;
  final DateTime createdAt;

  /// F3-09 — options figées à la commande (noms et suppléments de l'époque).
  final List<LineOption> options;

  /// F3-09 — part des options dans [prix] (ventilation, jamais à rajouter).
  final int optionsTotalXaf;
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
    this.options = const [],
    this.optionsTotalXaf = 0,
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
      options: LineOption.listFrom(json['options']),
      optionsTotalXaf: _asInt(json['optionsTotalXaf']),
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
