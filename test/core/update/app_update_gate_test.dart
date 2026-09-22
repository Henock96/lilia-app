import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/update/app_update_gate.dart';
import 'package:lilia_app/core/update/app_update_service.dart';
import 'package:lilia_app/core/update/app_version.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cycle de vie des dialogues de mise à jour (UPD-002, UPD-004).
///
/// Hôte minimal portant le mixin, comme `HomeScreen` : on vérifie le
/// comportement réel des dialogues (fermeture, réévaluation, échec du store)
/// sans monter tout l'écran d'accueil.

PlatformSettings _settings({String? min, String? latest}) => PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 50,
  loyaltyMinRedemption: 1,
  referrerBonusPoints: 1,
  minAppVersion: min,
  latestAppVersion: latest,
);

class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> with AppUpdateGate {
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('accueil')));
}

void main() {
  late PlatformSettings current;
  late ProviderContainer container;
  late bool storeOpens;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storeOpens = true;
  });

  Future<void> pumpHost(WidgetTester tester, PlatformSettings initial) async {
    current = initial;
    container = ProviderContainer(
      overrides: [
        platformSettingsProvider.overrideWith((ref) async => current),
        installedAppVersionProvider.overrideWith(
          (ref) async => AppVersion.parse('1.3.0+34'),
        ),
        appUpdateServiceProvider.overrideWithValue(
          AppUpdateService(
            platform: TargetPlatform.android,
            isWeb: false,
            canOpen: (_) async => true,
            open: (_) async => storeOpens,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _Host()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> publish(WidgetTester tester, PlatformSettings next) async {
    current = next;
    container.invalidate(platformSettingsProvider);
    await tester.pumpAndSettle();
  }

  testWidgets('blocage : dialogue obligatoire affiché', (tester) async {
    await pumpHost(tester, _settings(min: '1.3.1', latest: '1.3.1'));
    expect(find.text('Mise à jour requise'), findsOneWidget);
  });

  testWidgets('à jour : aucun dialogue', (tester) async {
    await pumpHost(tester, _settings(min: '1.3.0', latest: '1.3.0'));
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'store injoignable : message clair, dialogue maintenu, pas de faux succès',
    (tester) async {
      storeOpens = false;
      await pumpHost(tester, _settings(min: '1.3.1', latest: '1.3.1'));

      await tester.tap(find.text('Mettre à jour maintenant'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('store-open-failure')), findsOneWidget);
      expect(find.textContaining('Google Play'), findsOneWidget);
      expect(find.text('Copier le lien'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Mise à jour requise'), findsOneWidget);
    },
  );

  testWidgets('store ouvert : aucun message d’erreur', (tester) async {
    await pumpHost(tester, _settings(min: '1.3.1', latest: '1.3.1'));
    await tester.tap(find.text('Mettre à jour maintenant'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-open-failure')), findsNothing);
  });

  testWidgets(
    'blocage levé par l’administrateur : le dialogue obligatoire se referme',
    (tester) async {
      await pumpHost(tester, _settings(min: '1.3.1', latest: '1.3.1'));
      expect(find.text('Mise à jour requise'), findsOneWidget);

      await publish(tester, _settings(min: null, latest: '1.3.0'));

      expect(find.text('Mise à jour requise'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'retour dans l’app : les réglages sont relus et un blocage levé se referme',
    (tester) async {
      await pumpHost(tester, _settings(min: '1.3.1', latest: '1.3.1'));

      // L'administrateur lève le blocage pendant que l'app est en arrière-plan.
      current = _settings(min: null, latest: '1.3.0');
      // Transitions complètes : `AppLifecycleListener` refuse les sauts d'état.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(find.text('Mise à jour requise'), findsNothing);
    },
  );

  testWidgets(
    'facultative puis blocage publié : l’obligatoire prend la place',
    (tester) async {
      await pumpHost(tester, _settings(latest: '1.4.0'));
      expect(find.text('Nouvelle version disponible'), findsOneWidget);

      await publish(tester, _settings(min: '1.4.0', latest: '1.4.0'));

      expect(find.text('Nouvelle version disponible'), findsNothing);
      expect(find.text('Mise à jour requise'), findsOneWidget);
    },
  );

  testWidgets(
    'facultative fermée : pas de relance pour la même version, relance pour une nouvelle',
    (tester) async {
      await pumpHost(tester, _settings(latest: '1.4.0'));
      await tester.tapAt(const Offset(5, 5)); // tap hors du dialogue
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      await publish(tester, _settings(latest: '1.4.0'));
      expect(find.byType(Dialog), findsNothing);

      await publish(tester, _settings(latest: '1.5.0'));
      expect(find.text('Nouvelle version disponible'), findsOneWidget);
    },
  );

  testWidgets('« Plus tard » : reporté 24 h pour cette version', (tester) async {
    await pumpHost(tester, _settings(latest: '1.4.0'));
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(
      await AppUpdateService().shouldPromptOptionalUpdate('1.4.0'),
      isFalse,
    );
  });

  testWidgets(
    'facultative, store injoignable : le dialogue reste ouvert avec le message',
    (tester) async {
      storeOpens = false;
      await pumpHost(tester, _settings(latest: '1.4.0'));
      await tester.tap(find.text('Mettre à jour'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store-open-failure')), findsOneWidget);
      expect(find.text('Nouvelle version disponible'), findsOneWidget);
    },
  );
}
