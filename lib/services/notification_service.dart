import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lilia_app/constants/app_constants.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/firebase_options.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'notification_service.g.dart';

// --- Background Message Handler ---
// Doit être une fonction de haut niveau (en dehors d'une classe)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 1. Initialiser Firebase pour l'isolate d'arrière-plan
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Créer et afficher une notification locale
  // Cela garantit que l'utilisateur voit la notification même si l'application est terminée.
  if (message.notification != null) {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    // Initialisation pour Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await localNotifications.initialize(settings: initializationSettings);

    // Détails de la notification
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // Afficher la notification
    await localNotifications.show(
      id: message.notification.hashCode,
      title: message.notification!.title,
      body: message.notification!.body,
      notificationDetails: platformDetails,
      payload: jsonEncode(message.data), // Transmettre les données
    );
  }
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseAuthenticationRepository _authRepository;
  final http.Client _httpClient;
  final Ref _ref;

  // 🔥 AJOUT: Stream controllers pour éviter les erreurs de Subject fermé
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;
  // Flag pour savoir si le service a été dispose
  bool _isDisposed = false;
  NotificationService(this._authRepository, this._httpClient, this._ref);

  String? fcmToken;

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  void _setupMessageHandlers() {
    _cancelSubscriptions();
    // Gère le clic sur une notification lorsque l'application est en arrière-plan
    _onMessageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      debugPrint('Message opened from background: ${message.data}');
      if (message.data.containsKey('orderId')) {
        final orderId = message.data['orderId'] as String;
        // Mettre à jour l'état pour déclencher une navigation ou un rafraîchissement
        _ref.read(latestUpdatedOrderIdProvider.notifier).state = orderId;
        _ref.invalidate(userOrdersProvider);
      }
    });
    // Gère les messages lorsque l'application est au premier plan
    _onMessageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      debugPrint(
        'Message received while app is in foreground: ${message.notification?.title}',
      );
      if (message.notification != null) {
        _showLocalNotification(message); // Passer le message complet

        final notification = AppNotification(
          id: message.messageId ?? DateTime.now().timeZoneName,
          title: message.notification!.title ?? 'Sans titre',
          body: message.notification!.body ?? 'Sans contenu',
          timestamp: message.sentTime ?? DateTime.now(),
          payload: message.data,
        );

        _ref
            .read(notificationHistoryProvider.notifier)
            .addNotification(notification);

        if (message.data.containsKey('orderId')) {
          final orderId = message.data['orderId'] as String;
          _ref.read(latestUpdatedOrderIdProvider.notifier).state = orderId;
          _ref.invalidate(userOrdersProvider);
        }
      }
    });

    // Gère les messages en arrière-plan/terminé
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Améliorations pour votre NotificationService

  // 1. Support iOS dans _initLocalNotifications
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer le canal Android (important pour Android 8+)
    await _createNotificationChannel();
  }

  // 2. Création du canal de notification Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // 3. Méthode séparée pour gérer les clics sur notifications
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        debugPrint('Local notification tapped with payload: $data');
        _handleNotificationData(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  // 4. Centraliser la logique de traitement des données
  void _handleNotificationData(Map<String, dynamic> data) {
    if (data.containsKey('orderId')) {
      final orderId = data['orderId'] as String;
      _ref.read(latestUpdatedOrderIdProvider.notifier).state = orderId;
      _ref.invalidate(userOrdersProvider);
    }

    // Ajoutez d'autres types de données ici
    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'order_update':
          // Navigation vers la page commandes
          break;
        case 'message':
          // Navigation vers la messagerie
          break;
        default:
          // Action par défaut
          break;
      }
    }
  }

  // 5. Amélioration de _showLocalNotification avec support iOS
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          playSound: true,
          enableVibration: true,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  // 6. Méthode pour vérifier et demander les permissions locales
  Future<bool> _requestLocalNotificationPermission() async {
    final platform = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (platform != null) {
      return await platform.requestNotificationsPermission() ?? false;
    }

    final iosPlatform = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlatform != null) {
      return await iosPlatform.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  // 7. Amélioration de la méthode init avec gestion d'erreurs
  Future<void> init() async {
    if (_isDisposed) {
      debugPrint('⚠️ NotificationService already disposed, skipping init');
      return;
    }

    try {
      await _initLocalNotifications();

      // Vérifier les permissions locales
      final hasLocalPermission = await _requestLocalNotificationPermission();
      if (!hasLocalPermission) {
        debugPrint('Local notification permission denied');
      }

      await _requestPermission();

      fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        debugPrint('----------- FCM Token -----------');
        debugPrint(fcmToken);
        debugPrint('---------------------------------');

        // Enregistrer le token immédiatement
        await registerTokenOnServer();
      } else {
        debugPrint('Failed to get FCM token');
      }

      _setupMessageHandlers();
      _onTokenRefreshSubscription?.cancel();
      _onTokenRefreshSubscription = _fcm.onTokenRefresh.listen((newToken) {
        if (!_isDisposed) {
          debugPrint('FCM Token refreshed: $newToken');
          fcmToken = newToken;
          registerTokenOnServer();
        }
      });

      // Gérer l'ouverture de l'app via une notification (app terminée)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state via notification');
        _handleNotificationData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  // 8. Amélioration de registerTokenOnServer avec retry
  Future<void> registerTokenOnServer({int maxRetries = 3}) async {
    // Essayer d'obtenir le token si pas encore disponible (ex: init() appelé avant connexion)
    fcmToken ??= await _fcm.getToken();
    if (fcmToken == null) {
      debugPrint('FCM Token is null, cannot register on server.');
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final idToken = await _authRepository.getIdToken();
        if (idToken == null) {
          debugPrint(
            'Firebase ID Token is null, cannot authenticate to server.',
          );
          return;
        }

        final url = Uri.parse(
          '${AppConstants.baseUrl}/notifications/register-token',
        );

        final response = await _httpClient
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode({'token': fcmToken}),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('FCM Token registered successfully on the server.');
          return; // Succès, sortir de la boucle
        } else {
          debugPrint(
            'Failed to register FCM token (attempt $attempt/$maxRetries). '
            'Status: ${response.statusCode}, Body: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint(
          'Error registering FCM token (attempt $attempt/$maxRetries): $e',
        );

        if (attempt == maxRetries) {
          debugPrint('Max retries reached. Failed to register FCM token.');
        } else {
          // Attendre avant de réessayer
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
  }

  // Supprimer le token FCM du serveur (appeler au logout)
  Future<void> removeTokenFromServer() async {
    if (fcmToken == null) {
      debugPrint('FCM Token is null, nothing to remove from server.');
      return;
    }

    try {
      final idToken = await _authRepository.getIdToken();
      if (idToken == null) {
        debugPrint('Firebase ID Token is null, cannot remove FCM token.');
        return;
      }

      final url = Uri.parse(
        '${AppConstants.baseUrl}/notifications/token',
      );

      final response = await _httpClient
          .delete(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('FCM Token removed successfully from the server.');
      } else {
        debugPrint(
          'Failed to remove FCM token. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error removing FCM token from server: $e');
    }
  }

  // 🔥 MÉTHODE POUR NETTOYER LES SUBSCRIPTIONS
  void _cancelSubscriptions() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedSubscription?.cancel();
    _onTokenRefreshSubscription?.cancel();
  }

  // 🔥 MÉTHODE DISPOSE POUR NETTOYER LES RESSOURCES
  void dispose() {
    if (_isDisposed) return;

    debugPrint('🧹 Disposing NotificationService...');
    _isDisposed = true;

    _cancelSubscriptions();

    // Reset des variables
    _onMessageSubscription = null;
    _onMessageOpenedSubscription = null;
    _onTokenRefreshSubscription = null;
  }

  // 10. Méthode utilitaire pour tester les notifications locales
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id: 0,
      title: 'Test Notification',
      body: 'This is a test notification',
      notificationDetails: platformDetails,
    );
  }
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final httpClient = ref.watch(httpClientProvider);
  final service = NotificationService(authRepository, httpClient, ref);

  // 🔥 IMPORTANT: Nettoyer le service quand le provider est dispose
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}

extension RefExtensions on Ref {
  bool exists<T>(ProviderListenable<T> provider) {
    try {
      read(provider);
      return true;
    } catch (e) {
      return false;
    }
  }
}
