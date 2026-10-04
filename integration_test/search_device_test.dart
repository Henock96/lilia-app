// QA appareil réel — accueil et recherche, contre la production.
//
// ⚠️ LECTURE SEULE : aucun ajout au panier, aucun checkout, aucune écriture
// serveur. Le test ouvre des fiches et revient.
//
// Mesure, pour chaque requête réaliste : ce que l'écran affiche (sections,
// nombre de commandables / non commandables, badges), et toute exception de
// rendu (débordements compris) — à 1× puis 2× et en thème sombre.
//
// ⚠️ Jamais `pumpAndSettle` : le carrousel de l'accueil tourne en boucle.
//
//   flutter test integration_test/search_device_test.dart -d <iphone-udid>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lilia_app/features/home/presentation/search_screen.dart';
import 'package:lilia_app/features/home/presentation/widgets/search_bar_widget.dart';
import 'package:lilia_app/features/home/presentation/widgets/search_result_cards.dart';
import 'package:lilia_app/main.dart' as app;

final List<String> _exceptions = [];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA appareil : accueil puis recherche', (tester) async {
    final report = <String, Object?>{};
    final t0 = DateTime.now();
    app.main();
    // Première installation : l'onboarding passe d'abord. On relève ses
    // textes (promesses produit) et on le traverse comme un client.
    final onboardingTexts = <String>{};
    var home = false;
    final end = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(end)) {
      await _settle(tester, const Duration(milliseconds: 600));
      if (find.byType(SearchBarWidget).evaluate().isNotEmpty) {
        home = true;
        break;
      }
      for (final e in find.byType(Text).evaluate()) {
        final d = (e.widget as Text).data;
        if (d != null && d.trim().isNotEmpty) onboardingTexts.add(d);
      }
      for (final label in const ['Suivant', 'Commencer']) {
        final b = find.text(label).hitTestable();
        if (b.evaluate().isNotEmpty) {
          await tester.tap(b.first);
          break;
        }
      }
    }
    report['onboarding_textes'] = onboardingTexts.toList();
    report['home_ms'] = DateTime.now().difference(t0).inMilliseconds;
    expect(home, isTrue, reason: 'accueil jamais affiché');
    await _settle(tester, const Duration(seconds: 6));
    report['home_exceptions'] = List.of(_exceptions);
    _exceptions.clear();

    // ── Suggestions ────────────────────────────────────────────────────────
    await tester.tap(find.byType(SearchBarWidget));
    await _settle(tester, const Duration(seconds: 4));
    expect(find.byType(SearchScreen), findsOneWidget);
    report['suggestions'] = {
      'section': find.text('Suggestions').evaluate().isNotEmpty,
      'chips': find.byType(ActionChip).evaluate().length,
      'disponible_maintenant': find
          .text('Disponible maintenant')
          .evaluate()
          .isNotEmpty,
      'cartes': find.byType(SearchProductCard).evaluate().length,
      'message_soir': find
          .textContaining('Aucune boutique ne prend')
          .evaluate()
          .isNotEmpty,
    };

    for (final scale in const [1.0, 2.0]) {
      for (final dark in const [false, true]) {
        if (scale == 1.0 && dark) continue;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        final mode = '${scale}x${dark ? '-sombre' : ''}';
        final queries = scale == 1.0
            ? const [
                'p',
                'poulet',
                'pizza',
                'gâteau',
                'gateau',
                'burger',
                'riz',
                'jus',
                'beignet',
                'poulle',
              ]
            : const ['poulet', 'gâteau'];
        for (final q in queries) {
          report['$mode:$q'] = await _search(tester, q);
        }
      }
    }
    tester.platformDispatcher.clearAllTestValues();

    // ── Résultat → fiche → retour : la requête est-elle conservée ? ────────
    await _search(tester, 'poulet');
    final card = find.byType(SearchProductCard);
    if (card.evaluate().isNotEmpty) {
      await tester.tap(card.first);
      await _settle(tester, const Duration(seconds: 5));
      final onSearch = find.byType(SearchScreen).hitTestable();
      report['fiche_ouverte'] = onSearch.evaluate().isEmpty;
      await tester.binding.handlePopRoute();
      await _settle(tester, const Duration(seconds: 3));
      report['retour_requete_conservee'] =
          find.text('poulet').evaluate().isNotEmpty &&
          find.byType(SearchProductCard).evaluate().isNotEmpty;
    }
    final vendor = find.byType(SearchVendorCard);
    await _search(tester, 'first');
    if (vendor.evaluate().isNotEmpty) {
      await tester.tap(vendor.first);
      await _settle(tester, const Duration(seconds: 6));
      report['boutique_ouverte'] = find
          .byType(SearchScreen)
          .hitTestable()
          .evaluate()
          .isEmpty;
      await tester.binding.handlePopRoute();
      await _settle(tester, const Duration(seconds: 3));
      report['retour_boutique_requete_conservee'] = find
          .text('first')
          .evaluate()
          .isNotEmpty;
    }
    report['exceptions_fin'] = List.of(_exceptions);

    binding.reportData = {'qa_device': report};
    for (final e in report.entries) {
      debugPrint('QA ${e.key} => ${e.value}');
    }
  });
}

Future<Map<String, Object?>> _search(WidgetTester tester, String q) async {
  _exceptions.clear();
  final field = find.descendant(
    of: find.byType(SearchScreen),
    matching: find.byType(TextField),
  );
  final t0 = DateTime.now();
  await tester.enterText(field, q);
  await _settle(tester, const Duration(milliseconds: 400));
  await _pumpUntil(
    tester,
    find.byWidgetPredicate(
      (w) =>
          w is SearchSectionHeader ||
          (w is Text && (w.data ?? '').startsWith('Aucun résultat')) ||
          (w is Text && (w.data ?? '').contains('au moins 2 lettres')) ||
          (w is Text && (w.data ?? '') == 'Réessayer'),
    ),
    timeout: const Duration(seconds: 40),
  );
  final ms = DateTime.now().difference(t0).inMilliseconds;
  await _settle(tester, const Duration(milliseconds: 800));

  String? textOf(Finder f) =>
      f.evaluate().isEmpty ? null : (f.evaluate().first.widget as Text).data;
  final badges = <String, int>{};
  for (final label in const [
    'Fermé',
    'Épuisé',
    'Hors créneau',
    'Indisponible',
  ]) {
    final n = find.text(label).evaluate().length;
    if (n > 0) badges[label] = n;
  }
  return {
    'ms': ms,
    'resume': textOf(find.textContaining('résultat')),
    'boutiques': find.byType(SearchVendorCard).evaluate().length,
    'commandable': find.text('Commandable maintenant').evaluate().isNotEmpty,
    'pas_commandable': find
        .text('Pas commandable pour l’instant')
        .evaluate()
        .isNotEmpty,
    'badges': badges,
    'erreur': find.text('Réessayer').evaluate().isNotEmpty,
    'exceptions': List.of(_exceptions),
  };
}

Future<void> _settle(WidgetTester tester, Duration budget) async {
  final end = DateTime.now().add(budget);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    _collect(tester);
  }
}

Future<bool> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    _collect(tester);
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

void _collect(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) {
    final s = e.toString().split('\n').first;
    if (_exceptions.length < 20) _exceptions.add(s);
  }
}
