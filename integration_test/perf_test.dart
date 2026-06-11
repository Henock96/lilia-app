// Tests de performance automatisés (FPS / jank / réseau / montée en charge).
//
// Lancer sur device physique (chiffres réalistes) :
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart \
//     --profile \
//     -d <device-id> \
//     --dart-define=TEST_EMAIL=client@test.cg \
//     --dart-define=TEST_PASSWORD=Passw0rd!
//
// (Login optionnel : sans TEST_EMAIL, parcours en invité — la home est publique.)
//
// Timelines écrites par le driver dans build/ :
//   home_scroll / tab_navigation / search_scroll / restaurant_detail_scroll /
//   cart_scroll / stress  →  *.timeline_summary.json
// Métriques réseau custom → build/perf_metrics.json

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:lilia_app/main.dart' as app;

const String _email = String.fromEnvironment('TEST_EMAIL');
const String _password = String.fromEnvironment('TEST_PASSWORD');

late IntegrationTestWidgetsFlutterBinding _binding;
final Map<String, Object?> _metrics = <String, Object?>{};

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // fullyLive : les flings produisent de vraies frames pipelinées → mesure de
  // jank réaliste (sinon le test "saute" les frames intermédiaires).
  _binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Performance lilia-app', () {
    testWidgets('1. Démarrage à froid + chargement réseau home', (tester) async {
      final cold = Stopwatch()..start();
      await _bootApp(tester);
      await _maybeLogin(tester);
      final loaded = await _pumpUntil(
        tester,
        find.byType(Scrollable),
        timeout: const Duration(seconds: 40),
      );
      cold.stop();
      _metrics['cold_start_to_home_millis'] = cold.elapsedMilliseconds;
      _metrics['home_content_loaded'] = loaded;
      debugPrint('⏱️  Home prête en ${cold.elapsedMilliseconds} ms');
    });

    testWidgets('2. Scroll de la home (FPS / jank)', (tester) async {
      await _bootApp(tester);
      await _maybeLogin(tester);
      await _pumpUntil(tester, find.byType(Scrollable));
      final scrollable = find.byType(Scrollable).first;

      await _binding.traceAction(() async {
        for (var i = 0; i < 6; i++) {
          await tester.fling(scrollable, const Offset(0, -350), 3000);
          await tester.pumpAndSettle();
          await tester.fling(scrollable, const Offset(0, 350), 3000);
          await tester.pumpAndSettle();
        }
      }, reportKey: 'home_scroll');
    });

    testWidgets('3. Navigation entre les 4 onglets', (tester) async {
      await _bootApp(tester);
      await _maybeLogin(tester);
      await _pumpUntil(tester, find.text('Accueil'));

      await _binding.traceAction(() async {
        for (var i = 0; i < 5; i++) {
          for (final tab in const ['Panier', 'Commandes', 'Profil', 'Accueil']) {
            final finder = find.text(tab);
            if (finder.evaluate().isEmpty) continue;
            await tester.tap(finder.last);
            await tester.pumpAndSettle();
          }
        }
      }, reportKey: 'tab_navigation');
    });

    testWidgets('4. Recherche : saisie + scroll des résultats', (tester) async {
      await _bootApp(tester);
      await _maybeLogin(tester);
      // Ouvre l'écran de recherche depuis la barre de la home.
      final searchBar = find.text('Rechercher un plat, restaurant...');
      if (!await _pumpUntil(tester, searchBar)) {
        markTestSkipped('Barre de recherche introuvable');
        return;
      }
      await tester.tap(searchBar);
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      await tester.enterText(field.first, 'poulet');

      // Mesure le temps d'apparition des premiers résultats (appel réseau).
      final net = Stopwatch()..start();
      await _pumpUntil(
        tester,
        find.byType(ListTile),
        timeout: const Duration(seconds: 20),
      );
      net.stop();
      _metrics['search_first_result_millis'] = net.elapsedMilliseconds;

      final results = find.byType(Scrollable);
      if (results.evaluate().isNotEmpty) {
        await _binding.traceAction(() async {
          for (var i = 0; i < 4; i++) {
            await tester.fling(results.first, const Offset(0, -300), 3000);
            await tester.pumpAndSettle();
          }
        }, reportKey: 'search_scroll');
      }
      await _popOrHome(tester);
    });

    testWidgets('5. Détail vendeur : ouverture + scroll (images)', (tester) async {
      await _bootApp(tester);
      await _maybeLogin(tester);
      await _pumpUntil(tester, find.byType(Scrollable));

      // Scrolle un peu la home pour atteindre la liste verticale de vendeurs.
      await tester.fling(find.byType(Scrollable).first, const Offset(0, -600), 3000);
      await tester.pumpAndSettle();

      final card = find.byType(RestaurantCard);
      if (card.evaluate().isEmpty) {
        markTestSkipped('Aucune carte vendeur (données vides ?)');
        return;
      }

      final load = Stopwatch()..start();
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        find.byType(CustomScrollView),
        timeout: const Duration(seconds: 20),
      );
      load.stop();
      _metrics['vendor_detail_load_millis'] = load.elapsedMilliseconds;

      final detailScroll = find.byType(Scrollable);
      if (detailScroll.evaluate().isNotEmpty) {
        await _binding.traceAction(() async {
          for (var i = 0; i < 5; i++) {
            await tester.fling(detailScroll.first, const Offset(0, -400), 3500);
            await tester.pumpAndSettle();
            await tester.fling(detailScroll.first, const Offset(0, 400), 3500);
            await tester.pumpAndSettle();
          }
        }, reportKey: 'restaurant_detail_scroll');
      }
      await _popOrHome(tester);
    });

    testWidgets('6. Panier : ouverture + scroll', (tester) async {
      await _bootApp(tester);
      await _maybeLogin(tester);
      final cartTab = find.text('Panier');
      if (!await _pumpUntil(tester, cartTab)) {
        markTestSkipped('Onglet Panier introuvable');
        return;
      }
      await tester.tap(cartTab.last);
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await _binding.traceAction(() async {
          for (var i = 0; i < 4; i++) {
            await tester.fling(scrollable.first, const Offset(0, -300), 3000);
            await tester.pumpAndSettle();
            await tester.fling(scrollable.first, const Offset(0, 300), 3000);
            await tester.pumpAndSettle();
          }
        }, reportKey: 'cart_scroll');
      } else {
        markTestSkipped('Panier vide (rien à scroller)');
      }
    });

    testWidgets('7. Montée en charge (scroll + navigation soutenus)', (tester) async {
      await _bootApp(tester);
      await _maybeLogin(tester);
      await _pumpUntil(tester, find.byType(Scrollable));

      final stress = Stopwatch()..start();
      await _binding.traceAction(() async {
        for (var cycle = 0; cycle < 12; cycle++) {
          await tester.fling(find.byType(Scrollable).first, const Offset(0, -500), 4000);
          await tester.pumpAndSettle();
          for (final tab in const ['Commandes', 'Accueil']) {
            final f = find.text(tab);
            if (f.evaluate().isNotEmpty) {
              await tester.tap(f.last);
              await tester.pumpAndSettle();
            }
          }
        }
      }, reportKey: 'stress');
      stress.stop();
      _metrics['stress_total_millis'] = stress.elapsedMilliseconds;

      // Pousse les métriques custom dans le reportData renvoyé au driver.
      _binding.reportData ??= <String, dynamic>{};
      _binding.reportData!['perf_metrics'] = _metrics;
    });
  });
}

/// Démarre l'app réelle et laisse Firebase / Sentry / thème s'initialiser.
Future<void> _bootApp(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// Login optionnel : seulement si TEST_EMAIL est fourni et que l'écran de
/// connexion est présent (sinon déjà authentifié / parcours invité).
Future<void> _maybeLogin(WidgetTester tester) async {
  if (_email.isEmpty) return;
  final emailField = find.byKey(const Key('signin_email'));
  final onSignIn = await _pumpUntil(
    tester,
    emailField,
    timeout: const Duration(seconds: 8),
  );
  if (!onSignIn) return;
  await tester.enterText(emailField, _email);
  await tester.enterText(find.byKey(const Key('signin_password')), _password);
  await tester.tap(find.byKey(const Key('signin_submit')));
  await tester.pumpAndSettle(const Duration(seconds: 6));
}

/// Revient en arrière : BackButton de l'AppBar si présent, sinon onglet Accueil.
Future<void> _popOrHome(WidgetTester tester) async {
  final back = find.byType(BackButton);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
  } else {
    final home = find.text('Accueil');
    if (home.evaluate().isNotEmpty) await tester.tap(home.last);
  }
  await tester.pumpAndSettle();
}

/// Pompe des frames jusqu'à ce que [finder] existe ou que [timeout] expire.
/// Indispensable face aux appels réseau async (Render peut avoir un cold
/// start ~30s).
Future<bool> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}
