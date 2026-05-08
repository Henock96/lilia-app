// To parse this JSON data, do
//
//     final checkout = checkoutFromMap(jsonString);

import 'dart:convert';

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<dynamic> _asList(Object? value) => value is List ? value : <dynamic>[];

String _asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

int _asInt(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

DateTime _asDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

Checkout checkoutFromMap(String str) {
  final decoded = json.decode(str);
  final data = decoded is Map<String, dynamic> && decoded['data'] != null
      ? decoded['data']
      : decoded;
  return Checkout.fromMap(_asMap(data));
}

String checkoutToMap(Checkout data) => json.encode(data.toMap());

class Checkout {
  String id;
  String restaurantId;
  String userId;
  int subTotal;
  int deliveryFee;
  int serviceFee;
  int discountAmount;
  int total;
  String? promoCode;
  String? notes;
  String? deliveryAddress; // Nullable pour le mode retrait
  String paymentMethod;
  String status;
  DateTime createdAt;
  DateTime updatedAt;
  List<Item> items;
  bool isDelivery;

  Checkout({
    required this.id,
    required this.restaurantId,
    required this.userId,
    required this.subTotal,
    required this.deliveryFee,
    this.serviceFee = 0,
    this.discountAmount = 0,
    required this.total,
    this.promoCode,
    this.deliveryAddress, // Optionnel maintenant
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.notes,
    this.isDelivery = true,
  });

  Checkout copyWith({
    String? id,
    String? restaurantId,
    String? userId,
    int? subTotal,
    int? deliveryFee,
    int? serviceFee,
    int? discountAmount,
    int? total,
    String? promoCode,
    String? notes,
    String? deliveryAddress,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Item>? items,
    bool? isDelivery,
  }) => Checkout(
    id: id ?? this.id,
    restaurantId: restaurantId ?? this.restaurantId,
    userId: userId ?? this.userId,
    subTotal: subTotal ?? this.subTotal,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    serviceFee: serviceFee ?? this.serviceFee,
    discountAmount: discountAmount ?? this.discountAmount,
    total: total ?? this.total,
    promoCode: promoCode ?? this.promoCode,
    notes: notes ?? this.notes,
    deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    items: items ?? this.items,
    isDelivery: isDelivery ?? this.isDelivery,
  );

  factory Checkout.fromMap(Map<String, dynamic> json) => Checkout(
    id: _asString(json["id"]),
    restaurantId: _asString(json["restaurantId"]),
    userId: _asString(json["userId"]),
    subTotal: _asInt(json["subTotal"]),
    deliveryFee: _asInt(json["deliveryFee"]),
    serviceFee: (json["serviceFee"] as num?)?.toInt() ?? 0,
    discountAmount: (json["discountAmount"] as num?)?.toInt() ?? 0,
    total: _asInt(json["total"]),
    promoCode: json["promoCode"] is Map<String, dynamic>
        ? (_asMap(json["promoCode"])["code"] is String
              ? _asMap(json["promoCode"])["code"] as String
              : null)
        : json["promoCode"] is String
        ? json["promoCode"] as String
        : null,
    notes: json["notes"] is String ? json["notes"] as String : null,
    deliveryAddress: json["deliveryAddress"] is String
        ? json["deliveryAddress"] as String
        : null,
    paymentMethod: _asString(json["paymentMethod"]),
    status: _asString(json["status"]),
    createdAt: _asDate(json["createdAt"]),
    updatedAt: _asDate(json["updatedAt"]),
    items: _asList(
      json["items"],
    ).whereType<Map<String, dynamic>>().map(Item.fromMap).toList(),
    isDelivery: json["isDelivery"] is bool ? json["isDelivery"] as bool : true,
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "restaurantId": restaurantId,
    "userId": userId,
    "subTotal": subTotal,
    "deliveryFee": deliveryFee,
    "serviceFee": serviceFee,
    "discountAmount": discountAmount,
    "total": total,
    "promoCode": promoCode,
    "notes": notes,
    "deliveryAddress": deliveryAddress,
    "paymentMethod": paymentMethod,
    "status": status,
    "createdAt": createdAt.toIso8601String(),
    "updatedAt": updatedAt.toIso8601String(),
    "items": List<dynamic>.from(items.map((x) => x.toMap())),
    "isDelivery": isDelivery,
  };
}

class Item {
  String id;
  String orderId;
  String productId;
  String? menuId;
  String variant;
  int quantite;
  int prix;
  DateTime createdAt;

  Item({
    required this.id,
    required this.orderId,
    required this.productId,
    this.menuId,
    required this.variant,
    required this.quantite,
    required this.prix,
    required this.createdAt,
  });

  Item copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? menuId,
    String? variant,
    int? quantite,
    int? prix,
    DateTime? createdAt,
  }) => Item(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    productId: productId ?? this.productId,
    menuId: menuId ?? this.menuId,
    variant: variant ?? this.variant,
    quantite: quantite ?? this.quantite,
    prix: prix ?? this.prix,
    createdAt: createdAt ?? this.createdAt,
  );

  factory Item.fromMap(Map<String, dynamic> json) => Item(
    id: _asString(json["id"]),
    orderId: _asString(json["orderId"]),
    productId: _asString(json["productId"]),
    menuId: json["menuId"] is String ? json["menuId"] as String : null,
    variant: _asString(json["variant"], 'Standard'),
    quantite: _asInt(json["quantite"]),
    prix: _asInt(json["prix"]),
    createdAt: _asDate(json["createdAt"]),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "orderId": orderId,
    "productId": productId,
    "menuId": menuId,
    "variant": variant,
    "quantite": quantite,
    "prix": prix,
    "createdAt": createdAt.toIso8601String(),
  };
}
