import 'package:lilia_app/models/order_item.dart';

// Enum pour les statuts de commande, doit correspondre au backend
enum OrderStatus {
  enAttente,
  enPreparation,
  pret,
  livrer,
  annuler,
  unknow, // Pour les cas inattendus
}

// Fonction helper pour convertir String en OrderStatus
OrderStatus _parseStatus(String status) {
  switch (status) {
    case 'EN_ATTENTE':
      return OrderStatus.enAttente;
    case 'EN_PREPARATION':
      return OrderStatus.enPreparation;
    case 'PRET':
      return OrderStatus.pret;
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
  final double total;
  final String? deliveryAddress; // Nullable pour le mode retrait
  final String paymentMethod;
  final OrderStatus status; // Changé de String à OrderStatus
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderRestaurant restaurant;
  final List<OrderItem> items;
  final bool isDelivery; // Mode de livraison

  Order({
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
    required this.restaurant,
    required this.items,
    this.isDelivery = true,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<OrderItem> items = itemsList
        .map((i) => OrderItem.fromJson(i))
        .toList();

    return Order(
      id: json['id'],
      restaurantId: json['restaurantId'],
      userId: json['userId'],
      subTotal: (json['subTotal'] as num).toDouble(),
      deliveryFee: (json['deliveryFee'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      deliveryAddress: json['deliveryAddress'], // Peut être null en mode retrait
      paymentMethod: json['paymentMethod'],
      status: _parseStatus(json['status']), // Utilise la fonction de parsing
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      restaurant: OrderRestaurant.fromJson(json['restaurant']),
      items: items,
      isDelivery: json['isDelivery'] ?? true,
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
      nom: json['nom'],
      adresse: json['adresse'],
      imageUrl: json['imageUrl'],
    );
  }
}
