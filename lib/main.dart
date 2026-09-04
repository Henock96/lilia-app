import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/common_widgets/connectivity_banner.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:lilia_app/services/notification_service.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:lilia_app/theme/theme_mode_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'features/auth/user_sync_provider.dart';
import 'firebase_options.dart';

final notificationInitializerProvider = FutureProvider<void>((ref) async {
  await ref.watch(notificationServiceProvider).init();
});
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cache mémoire images plafonné à 100 MB (LIL-37).
  LiliaImageCache.configureMemoryCache();
  // Les polices (Inter, Oswald, Fraunces, Girassol, Lora) sont embarquées dans
  // le bundle : plus aucun appel à fonts.gstatic.com au premier lancement.
  // Sans ce flag, `google_fonts` retenterait quand même le réseau — latence au
  // démarrage sur la 4G de Brazzaville, et dépendance à un tiers.
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await initializeDateFormatting('fr_FR', null);
  AnalyticsService.setUserProperties();

  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).init();

  // DSN injecté au build via --dart-define=SENTRY_DSN=... (jamais en dur).
  // DSN vide => Sentry se désactive tout seul, l'appRunner s'exécute quand même.
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.environment = const String.fromEnvironment(
        'SENTRY_ENV',
        defaultValue: 'production',
      );
      options.tracesSampleRate = 0.1;
      // ignore: experimental_member_use
      options.profilesSampleRate = 0.1;
      // Le contexte user (id/email/role) est attaché explicitement après login.
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(notificationInitializerProvider);
    ref.watch(userDataSynchronizerProvider);
    return ConnectivityWrapper(
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        title: 'Lilia Food',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
      ),
    );
  }
}
