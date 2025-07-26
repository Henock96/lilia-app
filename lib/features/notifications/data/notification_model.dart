import 'dart:convert';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.payload = const {},
  });

  // Méthodes pour la sérialisation/désérialisation JSON (pour SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory AppNotification.fromJson(String source) =>
      AppNotification.fromMap(json.decode(source));
}
