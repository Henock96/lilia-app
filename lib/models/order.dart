import 'package:lilia_app/models/order_item.dart';

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<dynamic> _asList(Object? value) => value is List ? value : <dynamic>[];

String _asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

double _asDouble(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

DateTime _asDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

// Enum pour les statuts de commande, doit correspondre au backend
enum OrderStatus {
  enAttente,
  payer,
  enPreparation,
  pret,
  enRoute,
  livrer,
  annuler,
  unknow,
}

OrderStatus _parseStatus(String? status) {
  switch (status) {
    case 'EN_ATTENTE':
      return OrderStatus.enAttente;
    case 'PAYER':
      return OrderStatus.payer;
    case 'EN_PREPARATION':
      return OrderStatus.enPreparation;
    case 'PRET':
      return OrderStatus.pret;
    case 'EN_ROUTE':
      return OrderStatus.enRoute;
    case 'LIVRER':
      return OrderStatus.livrer;
    case 'ANNULER':
      return OrderStatus.annuler;
    default:
      return OrderStatus.unknow;
  }
}

class Order {
  final String id;
  final String restaurantId;
  final String userId;
  final double subTotal;
  final double deliveryFee;
  final double serviceFee;
  final double discountAmount;
  final double total;
  final String? deliveryAddress; // Nullable pour le mode retrait
  final String paymentMethod;
  final OrderStatus status; // Changé de String à OrderStatus
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderRestaurant restaurant;
  final List<OrderItem> items;
  final bool isDelivery; // Mode de livraison
  final bool isPreorder; // Commande programmée (précommande)
  final DateTime? scheduledFor; // Créneau de réception choisi (précommande)

  Order({
    required this.id,
    required this.restaurantId,
    required this.userId,
    required this.subTotal,
    required this.deliveryFee,
    this.serviceFee = 0,
    this.discountAmount = 0,
    required this.total,
    this.deliveryAddress, // Optionnel maintenant
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.restaurant,
    required this.items,
    this.isDelivery = true,
    this.isPreorder = false,
    this.scheduledFor,
  });

  Order copyWith({
    String? id,
    String? restaurantId,
    String? userId,
    double? subTotal,
    double? deliveryFee,
    double? serviceFee,
    double? discountAmount,
    double? total,
    String? deliveryAddress,
    String? paymentMethod,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    OrderRestaurant? restaurant,
    List<OrderItem>? items,
    bool? isDelivery,
    bool? isPreorder,
    DateTime? scheduledFor,
  }) {
    return Order(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      userId: userId ?? this.userId,
      subTotal: subTotal ?? this.subTotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      serviceFee: serviceFee ?? this.serviceFee,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      restaurant: restaurant ?? this.restaurant,
      items: items ?? this.items,
      isDelivery: isDelivery ?? this.isDelivery,
      isPreorder: isPreorder ?? this.isPreorder,
      scheduledFor: scheduledFor ?? this.scheduledFor,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final items = _asList(
      json['items'],
    ).whereType<Map<String, dynamic>>().map(OrderItem.fromJson).toList();

    return Order(
      id: _asString(json['id']),
      restaurantId: _asString(json['restaurantId']),
      userId: _asString(json['userId']),
      subTotal: _asDouble(json['subTotal']),
      deliveryFee: _asDouble(json['deliveryFee']),
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      total: _asDouble(json['total']),
      deliveryAddress: json['deliveryAddress'] is String
          ? json['deliveryAddress'] as String
          : null,
      paymentMethod: _asString(json['paymentMethod']),
      status: _parseStatus(json['status'] as String?),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
      restaurant: OrderRestaurant.fromJson(_asMap(json['restaurant'])),
      items: items,
      isDelivery: json['isDelivery'] is bool
          ? json['isDelivery'] as bool
          : true,
      isPreorder: json['isPreorder'] is bool
          ? json['isPreorder'] as bool
          : false,
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.tryParse(json['scheduledFor'].toString())
          : null,
    );
  }
}

class OrderRestaurant {
  final String nom;
  final String? adresse;
  final String? imageUrl;

  OrderRestaurant({required this.nom, this.adresse, this.imageUrl});

  factory OrderRestaurant.fromJson(Map<String, dynamic> json) {
    return OrderRestaurant(
      nom: _asString(json['nom'], 'Restaurant'),
      adresse: json['adresse'] is String ? json['adresse'] as String : null,
      imageUrl: json['imageUrl'] is String ? json['imageUrl'] as String : null,
    );
  }
}
