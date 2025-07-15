import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/routing/app_router.dart';

import 'features/auth/user_sync_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En "regardant" (watching) le provider, même si vous n'utilisez pas directement sa valeur,
    // cela garantit que son `build` (et donc son `ref.listen`) est exécuté.
    // L'AsyncValue de type <void> n'est pas utilisé directement ici.
    final GoRouter router = ref.watch(routerProvider);
    ref.watch(userDataSynchronizerProvider);
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'Lilia App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        fontFamily: 'Lora'
      ),
    );
  }
}
