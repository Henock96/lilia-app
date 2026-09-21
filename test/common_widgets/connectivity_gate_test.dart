// L'expérience hors ligne — **et le fait qu'elle ne déplace rien.**
//
// Historique des défauts couverts ici :
//   a) `ConnectivityBanner` n'était monté nulle part ;
//   b) `ConnectivityWrapper` était monté AU-DESSUS de `MaterialApp`, donc son
//      `ScaffoldMessenger.of(context)` levait à chaque bascule ;
//   c) le premier état de connectivité était perdu ;
//   d) le bandeau, posé dans une `Column`, **faisait descendre l'`AppBar`** ;
//   e) au rétablissement, le message ne partait pas — un événement perdu dans
//      le trou asynchrone d'un `async*` sur `StreamController.broadcast`.
//
// (d) et (e) sont des régressions introduites par le premier correctif : les
// deux tests qui les couvrent sont donc les plus importants du fichier.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/connectivity_banner.dart';
import 'package:lilia_app/services/connectivity_service.dart';

/// Double du plugin : on décide quand l'état courant répond, et quand les
/// changements arrivent.
class _FauxConnectivity implements Connectivity {
  _FauxConnectivity({this.etatInitial = const [ConnectivityResult.wifi]});

  final List<ConnectivityResult> etatInitial;
  final changements = StreamController<List<ConnectivityResult>>.broadcast();

  /// Retient la réponse à `checkConnectivity` — sert à provoquer le trou
  /// asynchrone que le défaut (e) exploitait.
  Completer<void>? porte;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      changements.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (porte != null) await porte!.future;
    return etatInitial;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

void main() {
  late StreamController<bool> reseau;

  /// Monte la grille **là où l'application la monte** : dans
  /// `MaterialApp.builder`, donc sous le `ScaffoldMessenger`.
  Future<void> monter(WidgetTester tester, {bool? etatInitial}) async {
    reseau = StreamController<bool>.broadcast();
    addTearDown(reseau.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStatusProvider.overrideWith((ref) async* {
            if (etatInitial != null) yield etatInitial;
            yield* reseau.stream;
          }),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              ConnectivityGate(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            appBar: AppBar(title: const Text('Titre')),
            body: const Center(child: Text('écran')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Laisse passer le temps **et** les frames.
  ///
  /// `pump(3s)` avance l'horloge et rend UNE frame : un minuteur qui tire
  /// pendant cet intervalle programme un `setState` qui n'est appliqué qu'à la
  /// frame suivante, et l'`AnimatedSwitcher` ne retire son ancien enfant qu'une
  /// frame après la fin de sa transition. Sans ces pompes supplémentaires, le
  /// test observe un arbre qui n'a pas fini de changer — et conclut que le
  /// bandeau « reste », ce qui est précisément le défaut qu'il cherche.
  Future<void> stabiliser(
    WidgetTester tester, [
    Duration ecoule = const Duration(milliseconds: 400),
  ]) async {
    await tester.pump();
    await tester.pump(ecoule);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  // Des `Finder` sont réutilisables : un `get` local n'est pas permis dans un
  // corps de fonction.
  final bandeauHorsLigne = find.text('Pas de connexion internet');
  final bandeauRetabli = find.text('Connexion rétablie');

  group('affichage', () {
    testWidgets('c) démarrage HORS LIGNE : le bandeau est là tout de suite', (
      tester,
    ) async {
      await monter(tester, etatInitial: false);

      expect(bandeauHorsLigne, findsOneWidget);
      expect(find.text('écran'), findsOneWidget);
    });

    testWidgets('démarrage EN LIGNE : aucun bandeau', (tester) async {
      await monter(tester, etatInitial: true);

      expect(bandeauHorsLigne, findsNothing);
      expect(bandeauRetabli, findsNothing);
    });

    testWidgets('a+b) en ligne → hors ligne : bandeau, et aucune exception', (
      tester,
    ) async {
      await monter(tester, etatInitial: true);

      reseau.add(false);
      await stabiliser(tester);

      expect(tester.takeException(), isNull);
      expect(bandeauHorsLigne, findsOneWidget);
    });
  });

  group('d) le bandeau ne déplace RIEN', () {
    testWidgets('l’AppBar est au même pixel, hors ligne ou non', (
      tester,
    ) async {
      await monter(tester, etatInitial: true);
      final avant = tester.getRect(find.byType(AppBar));
      final corpsAvant = tester.getRect(find.text('écran'));

      reseau.add(false);
      await stabiliser(tester);
      expect(bandeauHorsLigne, findsOneWidget);

      expect(
        tester.getRect(find.byType(AppBar)),
        avant,
        reason:
            'posé dans une `Column`, le bandeau poussait l’AppBar vers le bas '
            'de toute sa hauteur — plus celle de l’encoche avec la SafeArea',
      );
      expect(
        tester.getRect(find.text('écran')),
        corpsAvant,
        reason: 'le corps de l’écran ne doit pas bouger non plus',
      );
    });

    testWidgets('le bandeau n’intercepte aucun tap', (tester) async {
      await monter(tester, etatInitial: false);
      expect(bandeauHorsLigne, findsOneWidget);

      // Un `IgnorePointer` enveloppe le bandeau : un widget purement
      // informatif ne doit pas voler les gestes de ce qu'il survole.
      expect(
        find.ancestor(
          of: bandeauHorsLigne,
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });
  });

  group('e) le message de rétablissement PART', () {
    testWidgets('hors ligne → en ligne : « rétablie » puis plus rien', (
      tester,
    ) async {
      await monter(tester, etatInitial: false);
      expect(bandeauHorsLigne, findsOneWidget);

      reseau.add(true);
      await stabiliser(tester);

      expect(tester.takeException(), isNull);
      expect(bandeauRetabli, findsOneWidget);
      expect(
        bandeauHorsLigne,
        findsNothing,
        reason: 'le bandeau porte l’état : il ne survit pas au rétablissement',
      );

      // Et il s'efface tout seul, sans que personne n'ait à le retirer.
      await stabiliser(tester, const Duration(seconds: 3));
      expect(
        bandeauRetabli,
        findsNothing,
        reason:
            'c’est la plainte : le message restait à l’écran après le retour '
            'de la connexion',
      );
    });

    testWidgets('une rechute pendant l’annonce repasse au rouge', (
      tester,
    ) async {
      await monter(tester, etatInitial: false);

      reseau.add(true);
      await stabiliser(tester);
      expect(bandeauRetabli, findsOneWidget);

      // Le réseau retombe avant la fin des 2,5 s.
      reseau.add(false);
      await stabiliser(tester);

      expect(bandeauHorsLigne, findsOneWidget);
      expect(bandeauRetabli, findsNothing);

      // Et le minuteur de l'annonce précédente ne doit pas venir l'effacer.
      await stabiliser(tester, const Duration(seconds: 3));
      expect(bandeauHorsLigne, findsOneWidget);
    });

    testWidgets('un aller-retour complet ne laisse aucune exception', (
      tester,
    ) async {
      await monter(tester, etatInitial: true);

      for (final enLigne in <bool>[false, true, false, true]) {
        reseau.add(enLigne);
        await stabiliser(tester, const Duration(seconds: 4));
        expect(tester.takeException(), isNull);
      }

      expect(bandeauHorsLigne, findsNothing);
      expect(bandeauRetabli, findsNothing);
    });
  });

  group('e bis) la source n’a plus de trou asynchrone', () {
    testWidgets(
      'un changement pendant la lecture de l’état initial n’est PAS perdu',
      (tester) async {
        final plugin = _FauxConnectivity(
          etatInitial: const [ConnectivityResult.wifi],
        );
        addTearDown(plugin.changements.close);
        // `checkConnectivity` est retenu : c'est exactement la fenêtre où
        // l'ancienne implémentation perdait les événements.
        plugin.porte = Completer<void>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [connectivityProvider.overrideWithValue(plugin)],
            child: MaterialApp(
              builder: (context, child) =>
                  ConnectivityGate(child: child ?? const SizedBox.shrink()),
              home: const Scaffold(body: Text('écran')),
            ),
          ),
        );
        await tester.pump();

        // La coupure survient PENDANT la lecture de l'état initial.
        plugin.changements.add(const [ConnectivityResult.none]);
        await stabiliser(tester);

        expect(
          bandeauHorsLigne,
          findsOneWidget,
          reason:
              'l’abonnement est posé AVANT la lecture de l’état courant : '
              'aucun événement ne peut tomber entre les deux',
        );

        // L'état initial arrive ensuite, et il est plus ancien : il ne doit
        // pas ressusciter une connexion qui n'existe plus… mais il est légitime
        // qu'il s'applique, faute d'horodatage. On vérifie seulement qu'aucune
        // exception n'est levée et que le flux reste vivant.
        plugin.porte!.complete();
        await stabiliser(tester);
        expect(tester.takeException(), isNull);

        plugin.changements.add(const [ConnectivityResult.none]);
        await stabiliser(tester);
        expect(bandeauHorsLigne, findsOneWidget);
      },
    );
  });
}
