// Recherche : succès, vide, erreur, reprise.
//
// L'erreur s'affichait « Erreur: $err » — texte technique, sans bouton. Et
// derrière la relance automatique de Riverpod 3, elle ne s'affichait qu'après
// ~38 s de spinner. Ces tests passent SANS désactiver cette relance : c'est
// précisément elle qu'il fallait traverser.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/home/data/remote/home_repo.dart';
import 'package:lilia_app/features/home/presentation/search_screen.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/search_result.dart';
import 'package:lilia_app/theme/app_theme.dart';

/// Serveur simulé : tant que [panne] est posée, chaque appel échoue — y
/// compris les relances automatiques de Riverpod.
class _FauxDepot implements HomeRepository {
  Object? panne;
  SearchResult resultat = SearchResult(restaurants: [], products: []);
  final List<String> requetes = [];

  @override
  Future<SearchResult> search(String query) async {
    requetes.add(query);
    if (panne != null) throw panne!;
    return resultat;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

SearchResult _unPlat() => SearchResult(
  restaurants: [],
  products: [
    Product(
      id: 'p1',
      name: 'Poulet braisé',
      description: '',
      prixOriginal: 6000,
      imageUrl: null,
      restaurantId: 'resto-1',
      categoryId: null,
      isAvailable: true,
      variants: [ProductVariant(id: 'v1', label: 'Entier', prix: 6000)],
    ),
  ],
);

void main() {
  late _FauxDepot depot;

  Future<void> chercher(WidgetTester tester, String texte) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeRepositoryProvider.overrideWithValue(depot)],
        child: MaterialApp(theme: AppTheme.light, home: const SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), texte);
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await tester.pump(); // réponse
    await tester.pump(const Duration(milliseconds: 400)); // animations d'entrée
  }

  setUp(() => depot = _FauxDepot());

  testWidgets('succès : les plats trouvés s\'affichent', (tester) async {
    depot.resultat = _unPlat();
    await chercher(tester, 'poulet');
    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(depot.requetes, ['poulet']);
  });

  testWidgets('vide : un message nomme la recherche', (tester) async {
    await chercher(tester, 'xyz');
    expect(find.text('Aucun résultat pour "xyz"'), findsOneWidget);
  });

  testWidgets(
    'erreur : message client + Réessayer, tout de suite, sans détail technique',
    (tester) async {
      depot.panne = const ApiException(
        'Connexion impossible. Vérifiez votre réseau.',
        kind: ApiErrorKind.network,
      );
      await chercher(tester, 'poulet');

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      await tester.pumpWidget(const SizedBox()); // libère les relances
    },
  );

  testWidgets('erreur interne : jamais affichée brute', (tester) async {
    depot.panne = TypeError();
    await chercher(tester, 'poulet');

    expect(find.textContaining('TypeError'), findsNothing);
    expect(
      find.text(
        'Une erreur inattendue est survenue. Réessayez dans un instant.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Réessayer relance la même recherche et affiche le résultat', (
    tester,
  ) async {
    depot
      ..panne = const ApiException(
        'Serveur indisponible.',
        kind: ApiErrorKind.server,
      )
      ..resultat = _unPlat();
    await chercher(tester, 'poulet');
    expect(find.text('Réessayer'), findsOneWidget);

    depot.panne = null; // le serveur revient
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(depot.requetes.last, 'poulet', reason: 'même requête relancée');
    // La relance automatique programmée avant le tap arrive à échéance
    // (≤ 6,4 s) : elle ne doit pas produire de requête fantôme.
    final avant = depot.requetes.length;
    await tester.pump(const Duration(seconds: 7));
    expect(depot.requetes.length, avant);
  });
}
