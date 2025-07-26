import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/features/notifications/data/notification_model.dart';

class NotificationService {
  final _client = http.Client();
  // TODO: Remplacez par votre URL de production Render
  final _url = Uri.parse('https://lilia-backend.onrender.com/notifications/sse');

  Stream<AppNotification> connect() {
    final request = http.Request('GET', _url);

    // Ajout d'un en-tête pour maintenir la connexion ouverte
    request.headers['Cache-Control'] = 'no-cache';
    request.headers['Accept'] = 'text/event-stream';

    return _client.send(request).asStream().asyncExpand((response) {
      if (response.statusCode == 200) {
        return response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((line) => line.startsWith('data:'))
            .map((line) => line.substring(5).trim())
            .map((data) {
          final json = jsonDecode(data);
          // Assurez-vous que les clés correspondent à ce que votre backend envoie
          final orderId = json['id'] ?? 'N/A';
          final status = json['status'] ?? 'INCONNU';
          
          return AppNotification(
            id: orderId,
            title: 'Mise à jour de la commande',
            body: 'Le statut de votre commande est maintenant : $status',
            timestamp: DateTime.now(),
            payload: Map<String, dynamic>.from(json),
          );
        });
      } else {
        // Gérer les erreurs de connexion ici
        print('Failed to connect to SSE endpoint: ${response.statusCode}');
        throw Exception('Failed to connect to SSE endpoint: ${response.statusCode}');
      }
    });
  }

  void dispose() {
    _client.close();
  }
}


