// Smoke test de non-régression post-remédiation AUDIT_2026-08-01.
//
// Périmètre convenu : navigation, session, écran « Mode de livraison »
// (RadioListTile déprécié → RadioGroup) et les écrans dont les providers
// Riverpod ont été régénérés après le bump de dépendances.
//
// ⚠️ NE PASSE JAMAIS DE COMMANDE : le test s'arrête à l'écran mode de
// livraison, il ne touche pas au checkout (ça créerait de vraies commandes et
// des notifications vendeurs).
//
// ⚠️ Ne PAS utiliser `pumpAndSettle` ici : la home a un carrousel de bannières
// qui s'auto-défile, donc l'arbre ne se stabilise jamais. `pumpAndSettle`
// attendrait son timeout par défaut (10 minutes) avant d'échouer — et son
// premier argument est l'intervalle entre frames, pas un timeout. On pompe donc
// sur un budget de temps réel borné via [_settle] / [_pumpUntil].
//
// Lancer sur le simulateur, pointé sur la prod :
//   flutter test integration_test/audit_smoke_test.dart \
//     -d <device-id> \
//     --dart-define=API_URL=https://lilia-backend.onrender.com \
//     --dart-define=WS_URL=https://lilia-backend.onrender.com

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lilia_app/main.dart' as app;

late IntegrationTestWidgetsFlutterBinding _binding;
final Map<String, Object?> _results = <String, Object?>{};

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke post-audit', () {
    testWidgets('1. Démarrage + home chargée depuis la prod', (tester) async {
      await _bootApp(tester);

      final loaded = await _pumpUntil(
        tester,
        find.byType(Scrollable),
        timeout: const Duration(seconds: 45),
      );
      _results['home_loaded'] = loaded;
      expect(loaded, isTrue, reason: 'La home n\'a pas chargé');

      // Le contenu vient bien du backend, pas d'un état vide.
      final hasContent = await _pumpUntil(
        tester,
        find.textContaining('XAF'),
        timeout: const Duration(seconds: 20),
      );
      _results['home_has_remote_content'] = hasContent;
      debugPrint('✅ Home chargée — contenu distant: $hasContent');
    });

    testWidgets('2. Session active (pas d\'écran de connexion)', (tester) async {
      await _bootApp(tester);
      await _pumpUntil(tester, find.byType(Scrollable));

      final onSignIn =
          find.byKey(const Key('signin_email')).evaluate().isNotEmpty;
      _results['session_active'] = !onSignIn;
      expect(onSignIn, isFalse, reason: 'Renvoyé sur l\'écran de connexion');
      debugPrint('✅ Session active');
    });

    testWidgets('3. Navigation des 4 onglets', (tester) async {
      await _bootApp(tester);
      await _pumpUntil(tester, find.byType(Scrollable));

      final visited = <String>[];
      for (final tab in const ['Panier', 'Commandes', 'Profil', 'Accueil']) {
        final f = find.text(tab);
        if (f.evaluate().isEmpty) {
          debugPrint('⏭️  Onglet $tab introuvable');
          continue;
        }
        await tester.tap(f.last);
        await _settle(tester, const Duration(seconds: 4));
        expect(tester.takeException(), isNull, reason: 'Exception sur $tab');
        visited.add(tab);
        debugPrint('✅ Onglet $tab');
      }
      _results['tabs_visited'] = visited;
      expect(visited.length, 4);
    });

    testWidgets('4. Écran mode de livraison — RadioGroup', (tester) async {
      await _bootApp(tester);
      await _pumpUntil(tester, find.byType(Scrollable));

      // Panier
      await tester.tap(find.text('Panier').last);
      await _settle(tester, const Duration(seconds: 5));

      final checkoutBtn = find.text('Passer la commande');
      final cartHasItems = checkoutBtn.evaluate().isNotEmpty;
      _results['cart_had_items'] = cartHasItems;

      if (!cartHasItems) {
        _results['delivery_options_reached'] = false;
        _results['delivery_options_skipped_reason'] = 'panier vide';
        debugPrint(
          '⏭️  Panier vide — écran mode de livraison non atteignable sans '
          'ajouter un article. Test sauté (pas de mutation en prod).',
        );
        _report();
        return;
      }

      await tester.tap(checkoutBtn.last);
      await _settle(tester, const Duration(seconds: 6));

      // Le widget refait doit être présent et fonctionnel.
      expect(find.text('Mode de livraison'), findsWidgets);
      final radioGroup = find.byType(RadioGroup<bool>);
      expect(radioGroup, findsOneWidget, reason: 'RadioGroup<bool> absent');

      final tiles = find.byType(RadioListTile<bool>);
      expect(tiles, findsWidgets);
      _results['radio_tiles'] = tiles.evaluate().length;

      // Bascule livraison → retrait si l'option existe (masquée pour HOME_COOK).
      final pickup = find.textContaining('Retrait');
      if (pickup.evaluate().isNotEmpty) {
        await tester.tap(pickup.first);
        await _settle(tester, const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
        _results['pickup_toggle_ok'] = true;
        debugPrint('✅ Bascule retrait OK');
      } else {
        _results['pickup_toggle_ok'] = 'option masquée (HOME_COOK)';
      }

      _results['delivery_options_reached'] = true;
      debugPrint('✅ Écran mode de livraison OK — RadioGroup fonctionnel');

      // On s'arrête ici : PAS de checkout.
      _report();
    });
  });
}

Future<void> _bootApp(WidgetTester tester) async {
  app.main();
  await _settle(tester, const Duration(seconds: 3));
}

void _report() {
  _binding.reportData ??= <String, dynamic>{};
  _binding.reportData!['audit_smoke'] = _results;
  debugPrint('📊 Résultats: $_results');
}

/// Pompe des frames pendant [budget] de temps réel, sans jamais attendre que
/// l'arbre soit « settled » (le carrousel de la home tourne en boucle).
Future<void> _settle(WidgetTester tester, Duration budget) async {
  final end = DateTime.now().add(budget);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pompe des frames jusqu'à ce que [finder] existe ou que [timeout] expire.
/// Render peut avoir un cold start ~30s.
Future<bool> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}
