// To parse this JSON data, do
//
//     final checkout = checkoutFromMap(jsonString);

import 'dart:convert';

Checkout checkoutFromMap(String str) => Checkout.fromMap(json.decode(str)["data"]);

String checkoutToMap(Checkout data) => json.encode(data.toMap());

class Checkout {
  String id;
  String restaurantId;
  String userId;
  int subTotal;
  int deliveryFee;
  int total;
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
    required this.total,
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
    int? total,
    String? notes,
    String? deliveryAddress,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Item>? items,
    bool? isDelivery,
  }) =>
      Checkout(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        userId: userId ?? this.userId,
        subTotal: subTotal ?? this.subTotal,
        deliveryFee: deliveryFee ?? this.deliveryFee,
        total: total ?? this.total,
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
    id: json["id"],
    restaurantId: json["restaurantId"],
    userId: json["userId"],
    subTotal: json["subTotal"],
    deliveryFee: json["deliveryFee"],
    total: json["total"],
    notes: json["notes"],
    deliveryAddress: json["deliveryAddress"], // Peut être null en mode retrait
    paymentMethod: json["paymentMethod"],
    status: json["status"],
    createdAt: DateTime.parse(json["createdAt"]),
    updatedAt: DateTime.parse(json["updatedAt"]),
    items: List<Item>.from(json["items"].map((x) => Item.fromMap(x))),
    isDelivery: json["isDelivery"] ?? true,
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "restaurantId": restaurantId,
    "userId": userId,
    "subTotal": subTotal,
    "deliveryFee": deliveryFee,
    "total": total,
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
  }) =>
      Item(
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
    id: json["id"],
    orderId: json["orderId"],
    productId: json["productId"],
    menuId: json["menuId"],
    variant: json["variant"],
    quantite: json["quantite"],
    prix: json["prix"],
    createdAt: DateTime.parse(json["createdAt"]),
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
