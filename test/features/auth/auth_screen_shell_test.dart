// La flèche de retour des écrans d'authentification — et le retour matériel.
//
// `auth_exit_test` éprouve le CALCUL de la destination. Ce test-ci éprouve ce
// qu'aucune fonction pure ne peut attraper : que les deux gestes sont bien
// câblés sur ce calcul, et qu'ils vont au même endroit.
//
// Le harnais monte la coque seule, pas `SignInPage` : l'objet du test est la
// sortie, et les contrôleurs de formulaire n'y participent pas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/presentation/auth_screen_shell.dart';

/// Compte les constructions de l'écran de départ : c'est la mesure de ce que
/// coûte un retour.
int creationsPanier = 0;

class _PanierTemoin extends StatefulWidget {
  const _PanierTemoin();
  @override
  State<_PanierTemoin> createState() => _PanierTemoinState();
}

class _PanierTemoinState extends State<_PanierTemoin> {
  @override
  void initState() {
    super.initState();
    creationsPanier++;
  }

  @override
  Widget build(BuildContext context) => const Text('Panier');
}

GoRouter _routeur(String depart) => GoRouter(
  initialLocation: depart,
  routes: [
    GoRoute(
      path: '/signin',
      builder: (_, _) =>
          const AuthScreenShell(child: Text('Formulaire de connexion')),
    ),
    GoRoute(path: '/', builder: (_, _) => const Text('Accueil')),
    GoRoute(
      path: '/cart',
      builder: (_, _) => const _PanierTemoin(),
      routes: [
        GoRoute(
          path: 'delivery-options',
          builder: (_, _) => const Text('Livraison'),
        ),
      ],
    ),
  ],
);

void main() {
  late GoRouter routeur;

  Future<void> monter(WidgetTester tester, String depart) async {
    routeur = _routeur(depart);
    addTearDown(routeur.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: routeur));
    await tester.pumpAndSettle();
  }

  String emplacement() =>
      routeur.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('la flèche est présente alors que la pile est vide', (
    tester,
  ) async {
    await monter(tester, '/signin');
    // `BackButton` ne s'afficherait pas ici : `canPop()` est faux. C'est
    // exactement la raison d'être de ce bouton.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byTooltip('Retour'), findsOneWidget);
  });

  testWidgets('la flèche ramène au panier quand on venait du checkout', (
    tester,
  ) async {
    await monter(tester, '/signin?from=%2Fcart%2Fdelivery-options');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(emplacement(), '/cart');
    expect(find.text('Panier'), findsOneWidget);
  });

  testWidgets("la flèche ramène à l'accueil sans destination", (tester) async {
    await monter(tester, '/signin');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(emplacement(), '/');
  });

  testWidgets('le retour matériel fait la même chose que la flèche', (
    tester,
  ) async {
    await monter(tester, '/signin?from=%2Fcart%2Fdelivery-options');

    // Ce que produit le bouton « retour » d'Android.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Sans le `PopScope`, l'application se serait fermée : rien à dépiler.
    expect(emplacement(), '/cart');
  });

  testWidgets("quand une pile existe, le retour la dépile au lieu d'en "
      'construire une neuve', (tester) async {
    // `go` ne revient pas en arrière : il reconstruit. L'écran d'arrivée est
    // alors recréé et ses providers `autoDispose` redemandés au serveur. Ce
    // test compte les créations : si le retour repassait par `go`, le témoin
    // serait construit une seconde fois.
    creationsPanier = 0;
    routeur = _routeur('/cart');
    addTearDown(routeur.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: routeur));
    await tester.pumpAndSettle();
    expect(creationsPanier, 1);

    routeur.push('/signin?from=%2Fcart%2Fdelivery-options');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(emplacement(), '/cart');
    expect(
      creationsPanier,
      1,
      reason: "l'écran de départ ne doit pas être reconstruit",
    );
  });
}
