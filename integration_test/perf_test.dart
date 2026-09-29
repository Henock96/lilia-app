// ignore_for_file: avoid_print — en profile, seul `print` remonte à `flutter drive`.
// Tests de performance automatisés (FPS / jank / réseau / montée en charge).
//
// Lancer sur device physique (chiffres réalistes) :
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart \
//     --profile --no-dds \
//     -d <device-id> \
//     --dart-define=TEST_EMAIL=client@test.cg \
//     --dart-define=TEST_PASSWORD=Passw0rd!
//
// (Login optionnel : sans TEST_EMAIL, parcours en invité — la home est publique.)
//
// ⚠️ Trois défauts rendaient ce harnais inopérant (Discovery Phase 3, 29/09) :
//   1. `app.main()` était rappelé par chaque `testWidgets` : Firebase et le
//      `ProviderScope` étaient réinitialisés sur une app déjà montée, tests
//      2 à 7 en échec. L'app est désormais démarrée **une seule fois**.
//   2. Sur une installation neuve, le `PageView` de l'onboarding répondait à
//      `find.byType(Scrollable)` : on « mesurait » l'onboarding. L'onboarding
//      est marqué vu avant le démarrage, et l'accueil est reconnu à sa
//      première `RestaurantCard`.
//   3. `traceAction` échoue sans `--no-dds` (Flutter 3.47) : l'option est
//      dans la commande ci-dessus.
//
// Timelines écrites par le driver dans build/ :
//   home_scroll / tab_navigation / search_scroll / restaurant_detail_scroll /
//   cart_scroll / stress  →  *.timeline_summary.json
// Métriques réseau custom → build/perf_metrics.json

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

const String _email = String.fromEnvironment('TEST_EMAIL');
const String _password = String.fromEnvironment('TEST_PASSWORD');

/// En invité, « Commandes » et « Profil » ouvrent la connexion en plein
/// écran, **sans** barre d'onglets : le harnais y restait bloqué et tous les
/// tests suivants échouaient (« onglet introuvable »).
const List<String> _tabs = _email == ''
    ? ['Panier', 'Accueil']
    : ['Panier', 'Commandes', 'Profil', 'Accueil'];

late IntegrationTestWidgetsFlutterBinding _binding;
final Map<String, Object?> _metrics = <String, Object?>{};

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // En profile, flutter_test imprime « Instance of 'FlutterErrorDetails' »
  // sans message : on imprime le message et le haut de la pile.
  // ⚠️ Toujours relayer au rapporteur d'origine : c'est lui qui fait échouer
  // le test. Sans lui, la suite se déclarait verte (constaté le 29/09).
  final rapporteur = reportTestException;
  reportTestException = (details, description) {
    print('❌ [$description] ${details.exceptionAsString()}');
    print(details.stack.toString().split('\n').take(10).join('\n'));
    rapporteur(details, description);
  };
  // fullyLive : les flings produisent de vraies frames pipelinées → mesure de
  // jank réaliste (sinon le test "saute" les frames intermédiaires).
  _binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // UN SEUL `testWidgets` : flutter_test démonte l'arbre entre deux tests —
  // l'app démarrée au test 1 n'existait plus au test 2 (diagnostic du 29/09 :
  // « Accueil=0 cartes=0 »), et la redémarrer par test cassait Firebase.
  // Chaque scénario est isolé : un échec est journalisé et n'empêche pas les
  // suivants ; la suite échoue à la fin s'il y en a eu.
  testWidgets('Performance lilia-app — parcours complet', (tester) async {
    final echecs = <String>[];
    for (final (nom, scenario)
        in <(String, Future<void> Function(WidgetTester))>[
          ('1. Démarrage à froid + chargement réseau home', _scenario1),
          ('2. Scroll de la home (FPS / jank)', _scenario2),
          ('3. Navigation entre les 4 onglets', _scenario3),
          ('4. Recherche : saisie + scroll des résultats', _scenario4),
          ('5. Détail vendeur : ouverture + scroll (images)', _scenario5),
          ('6. Panier : ouverture + scroll', _scenario6),
          ('7. Montée en charge (scroll + navigation soutenus)', _scenario7),
        ]) {
      print('▶️ $nom');
      try {
        await scenario(tester);
      } catch (e, st) {
        echecs.add(nom);
        print('❌ [$nom] $e');
        print(st.toString().split('\n').take(8).join('\n'));
      }
    }
    // Pas de `fail()` ici : le driver n'écrit **aucun** résumé si le test
    // échoue. Les échecs lui sont transmis ; il écrit les mesures des
    // scénarios réussis puis sort en erreur (`test_driver/perf_driver.dart`).
    _binding.reportData ??= <String, dynamic>{};
    _binding.reportData!['perf_metrics'] = _metrics;
    _binding.reportData!['scenario_failures'] = echecs;
  });
}

/// 1. Démarrage à froid + chargement réseau home
Future<void> _scenario1(WidgetTester tester) async {
  final cold = Stopwatch()..start();
  await _bootApp(tester);
  await _maybeLogin(tester);
  final loaded = await _pumpUntil(
    tester,
    find.byType(RestaurantCard),
    timeout: const Duration(seconds: 40),
  );
  cold.stop();
  _metrics['cold_start_to_home_millis'] = cold.elapsedMilliseconds;
  _metrics['home_content_loaded'] = loaded;
  print('⏱️  Home prête en ${cold.elapsedMilliseconds} ms');
}

/// 2. Scroll de la home (FPS / jank)
Future<void> _scenario2(WidgetTester tester) async {
  await _bootApp(tester);
  await _maybeLogin(tester);
  await _pumpUntil(tester, _verticalScrollables());
  final scrollable = _verticalScrollable();

  await _trace(() async {
    for (var i = 0; i < 6; i++) {
      await tester.fling(scrollable, const Offset(0, -350), 3000);
      await _settle(tester);
      await tester.fling(scrollable, const Offset(0, 350), 3000);
      await _settle(tester);
    }
  }, reportKey: 'home_scroll');
}

/// 3. Navigation entre les 4 onglets
Future<void> _scenario3(WidgetTester tester) async {
  await _bootApp(tester);
  await _maybeLogin(tester);
  await _pumpUntil(tester, find.text('Accueil'));

  await _trace(() async {
    for (var i = 0; i < 5; i++) {
      for (final tab in _tabs) {
        final finder = find.text(tab);
        if (finder.evaluate().isEmpty) continue;
        await tester.tap(finder.last);
        await _settle(tester);
      }
    }
  }, reportKey: 'tab_navigation');
}

/// 4. Recherche : saisie + scroll des résultats
Future<void> _scenario4(WidgetTester tester) async {
  await _bootApp(tester);
  await _maybeLogin(tester);
  // Ouvre l'écran de recherche depuis la barre de la home.
  final searchBar = find.text('Rechercher un plat, restaurant...');
  if (!await _pumpUntil(tester, searchBar)) {
    _skip('Barre de recherche introuvable');
    return;
  }
  await tester.tap(searchBar);
  await _settle(tester);

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
    await _trace(() async {
      for (var i = 0; i < 4; i++) {
        await tester.fling(results.first, const Offset(0, -300), 3000);
        await _settle(tester);
      }
    }, reportKey: 'search_scroll');
  }
  await _popOrHome(tester);
}

/// 5. Détail vendeur : ouverture + scroll (images)
Future<void> _scenario5(WidgetTester tester) async {
  await _bootApp(tester);
  await _maybeLogin(tester);
  await _pumpUntil(tester, find.byType(Scrollable));

  // Scrolle un peu la home pour atteindre la liste verticale de vendeurs.
  await tester.fling(_verticalScrollable(), const Offset(0, -600), 3000);
  await _settle(tester);

  final card = find.byType(RestaurantCard);
  if (card.evaluate().isEmpty) {
    _skip('Aucune carte vendeur (données vides ?)');
    return;
  }

  final load = Stopwatch()..start();
  await tester.tap(card.first);
  await _settle(tester);
  await _pumpUntil(
    tester,
    find.byType(CustomScrollView),
    timeout: const Duration(seconds: 20),
  );
  load.stop();
  _metrics['vendor_detail_load_millis'] = load.elapsedMilliseconds;

  final detailScroll = find.byType(Scrollable);
  if (detailScroll.evaluate().isNotEmpty) {
    await _trace(() async {
      for (var i = 0; i < 5; i++) {
        await tester.fling(detailScroll.first, const Offset(0, -400), 3500);
        await _settle(tester);
        await tester.fling(detailScroll.first, const Offset(0, 400), 3500);
        await _settle(tester);
      }
    }, reportKey: 'restaurant_detail_scroll');
  }
  await _popOrHome(tester);
}

/// 6. Panier : ouverture + scroll
Future<void> _scenario6(WidgetTester tester) async {
  await _bootApp(tester);
  await _maybeLogin(tester);
  final cartTab = find.text('Panier');
  if (!await _pumpUntil(tester, cartTab)) {
    _skip('Onglet Panier introuvable');
    return;
  }
  await tester.tap(cartTab.last);
  await _settle(tester);

  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    await _trace(() async {
      for (var i = 0; i < 4; i++) {
        await tester.fling(scrollable.first, const Offset(0, -300), 3000);
        await _settle(tester);
        await tester.fling(scrollable.first, const Offset(0, 300), 3000);
        await _settle(tester);
      }
    }, reportKey: 'cart_scroll');
  } else {
    _skip('Panier vide (rien à scroller)');
  }
}

/// 7. Montée en charge (scroll + navigation soutenus)
Future<void> _scenario7(WidgetTester tester) async {
  await _bootApp(tester);
  await _maybeLogin(tester);
  await _pumpUntil(tester, find.byType(Scrollable));

  final stress = Stopwatch()..start();
  await _trace(() async {
    for (var cycle = 0; cycle < 12; cycle++) {
      await tester.fling(_verticalScrollable(), const Offset(0, -500), 4000);
      await _settle(tester);
      for (final tab in const ['Panier', 'Accueil']) {
        final f = find.text(tab);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.last);
          await _settle(tester);
        }
      }
    }
  }, reportKey: 'stress');
  stress.stop();
  _metrics['stress_total_millis'] = stress.elapsedMilliseconds;
}

bool _booted = false;

/// Démarre l'app réelle **une seule fois** pour toute la suite, onboarding
/// marqué vu. Les tests suivants repartent de l'écran courant.
Future<void> _bootApp(WidgetTester tester) async {
  // Profile : l'échec s'affiche « Instance of 'FlutterErrorDetails' ».
  // On imprime le message et le début de la pile avant de le transmettre.
  final framework = FlutterError.onError;
  FlutterError.onError = (details) {
    print('❌ ${details.exceptionAsString()}');
    print(details.stack.toString().split('\n').take(6).join('\n'));
    framework?.call(details);
  };
  if (_booted) {
    // Un test précédent a pu échouer sur un écran poussé (fiche vendeur…) :
    // retour système jusqu'à retrouver la barre d'onglets.
    for (var i = 0; i < 5 && find.text('Accueil').evaluate().isEmpty; i++) {
      await tester.binding.handlePopRoute();
      await _settle(tester);
    }
    final home = find.text('Accueil');
    if (home.evaluate().isNotEmpty) await tester.tap(home.last);
    await tester.pump(const Duration(milliseconds: 500));
    _diagnostic('après retour à l\'accueil');
    return;
  }
  _booted = true;
  final prefs = await SharedPreferences.getInstance();
  // Clé de `OnboardingStatus` (onboarding_provider.dart).
  await prefs.setBool('onboarding_completed', true);
  app.main();
  // Pas de `pumpAndSettle` : le carrousel de l'accueil s'auto-défile.
  await _pumpUntil(
    tester,
    find.byType(RestaurantCard),
    timeout: const Duration(seconds: 40),
  );
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
  await _pumpUntil(tester, find.byType(RestaurantCard));
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
  await _settle(tester);
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

/// Remplace `pumpAndSettle`, qui ne rend jamais la main sur l'accueil : le
/// carrousel s'auto-défile, l'arbre n'est jamais stable (voir CLAUDE.md).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Le défilement **vertical visible** de l'écran courant.
///
/// `find.byType(Scrollable).first` visait le premier `Scrollable` de l'arbre :
/// le carrousel horizontal, ou la liste d'un onglet hors écran (les branches
/// d'un `StatefulShellRoute` restent montées), sur lequel `fling` échoue.
Finder _verticalScrollable() => _verticalScrollables().first;

/// Sans `.first` : pour **attendre**. Évaluer un `.first` vide lève
/// « Bad state: No element » (flutter_test récent) au lieu de rendre vide —
/// `_pumpUntil` plantait au lieu d'attendre.
Finder _verticalScrollables() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .hitTestable();

/// `traceAction` avec une erreur **lisible** : en mode profile, un échec
/// s'affiche « Instance of 'FlutterErrorDetails' » sans message ni pile.
Future<void> _trace(
  Future<void> Function() action, {
  required String reportKey,
}) async {
  try {
    await _binding.traceAction(action, reportKey: reportKey);
  } catch (e, st) {
    print('❌ [$reportKey] $e');
    print(st.toString().split('\n').take(8).join('\n'));
    rethrow;
  }
}

/// État de l'écran, imprimé en tête de test : ce qu'un finder « introuvable »
/// ne dit pas.
void _diagnostic(String quand) {
  int n(Finder f) => f.evaluate().length;
  print(
    '🔎 $quand : onglet Accueil=${n(find.text('Accueil'))} '
    'cartes=${n(find.byType(RestaurantCard))} '
    'recherche=${n(find.text('Rechercher un plat, restaurant...'))} '
    'défilables=${n(find.byType(Scrollable))} '
    'défilables verticaux touchables=${n(_verticalScrollables())} '
    'dialogues=${n(find.byType(Dialog))} '
    'accueil visible=${n(find.byType(HomeScreen))}',
  );
}

/// Scénario non applicable (données vides…) : journalisé, pas d'échec.
void _skip(String raison) => print('⏭️ $raison');
