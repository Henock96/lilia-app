import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/services/notification_service.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'features/auth/user_sync_provider.dart';
import 'firebase_options.dart';

// Provider pour initialiser le service de notification au démarrage de l'application
final notificationInitializerProvider = FutureProvider<void>((ref) async {
  await ref.watch(notificationServiceProvider).init();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En "regardant" (watching) les providers, même si vous n'utilisez pas directement leur valeur,
    // cela garantit que leur logique d'initialisation est exécutée.
    final GoRouter router = ref.watch(routerProvider);
    final appTheme = AppTheme.theme;
    ref.watch(
      notificationInitializerProvider,
    ); // Déclenche l'initialisation des notifications
    ref.watch(userDataSynchronizerProvider);
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'Lilia App',
      theme: appTheme,
    );
  }
}
