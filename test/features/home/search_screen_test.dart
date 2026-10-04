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
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/presentation/quick_add.dart';
import 'package:lilia_app/features/home/data/remote/home_repo.dart';
import 'package:lilia_app/features/home/presentation/search_screen.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/search_result.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/fake_auth_repository.dart';

/// Serveur simulé : tant que [panne] est posée, chaque appel échoue — y
/// compris les relances automatiques de Riverpod.
class _FauxDepot implements HomeRepository {
  Object? panne;
  SearchResult resultat = SearchResult(restaurants: [], products: []);
  List<Product> disponibles = const [];
  final List<String> requetes = [];

  @override
  Future<AvailableNow> getAvailableNow({
    VendorType? vendorType,
    int limit = 10,
  }) async => AvailableNow(products: disponibles);

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

Product _plat(
  String id,
  String nom, {
  bool? boutiqueOuverte = true,
  String? stockStatus,
  String? categorie,
}) => Product(
  id: id,
  name: nom,
  description: 'Servi avec bananes plantains',
  prixOriginal: 3000,
  imageUrl: null,
  restaurantId: 'resto-1',
  restaurantName: 'Chez Lili',
  restaurantIsOpen: boutiqueOuverte,
  categoryId: categorie == null ? null : 'cat-$id',
  category: categorie == null ? null : Category(id: 'cat-$id', name: categorie),
  isAvailable: true,
  variants: [
    ProductVariant(id: 'v-$id', label: 'Portion', prix: 3000, stockStatus: stockStatus),
  ],
);

void main() {
  late _FauxDepot depot;

  Future<void> ouvrir(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeRepositoryProvider.overrideWithValue(depot),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: const AppUser(uid: 'uid-a')),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> chercher(WidgetTester tester, String texte) async {
    await ouvrir(tester);
    await tester.enterText(find.byType(TextField), texte);
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await tester.pump(); // réponse
    await tester.pump(const Duration(milliseconds: 400)); // animations d'entrée
  }

  setUp(() {
    depot = _FauxDepot();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'les plats commandables passent devant, les autres gardent leur raison '
    'et n’ont pas de bouton d’ajout',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      depot.resultat = SearchResult(
        restaurants: [],
        // Ordre serveur volontairement mélangé : le fermé arrive en premier.
        products: [
          _plat('p1', 'Poulet DG', boutiqueOuverte: false),
          _plat('p2', 'Poulet braisé'),
          _plat('p3', 'Poulet yassa', stockStatus: 'OUT_OF_STOCK'),
        ],
      );
      await chercher(tester, 'poulet');

      expect(find.text('Commandable maintenant'), findsOneWidget);
      expect(find.text('Pas commandable pour l’instant'), findsOneWidget);
      final dyCommandable = tester.getTopLeft(find.text('Poulet braisé')).dy;
      expect(dyCommandable, lessThan(tester.getTopLeft(find.text('Poulet DG')).dy));
      expect(find.text('Fermé'), findsOneWidget);
      expect(find.text('Épuisé'), findsOneWidget);
      expect(find.byType(QuickAddButton), findsOneWidget,
          reason: 'aucun « + » sur un plat que le serveur refuserait');
      expect(find.textContaining('1 plat commandable'), findsOneWidget);
    },
  );

  testWidgets('une seule lettre : aucune requête, on attend la suivante', (
    tester,
  ) async {
    await chercher(tester, 'p');
    expect(depot.requetes, isEmpty);
    expect(find.textContaining('au moins 2 lettres'), findsOneWidget);
  });

  testWidgets(
    'champ vide : suggestions tirées des plats commandables, sans doublon',
    (tester) async {
      depot.disponibles = [
        _plat('p1', 'Poulet braisé', categorie: 'Grillades'),
        _plat('p2', 'Brochettes', categorie: 'grillades'),
        _plat('p3', 'Croissant', categorie: 'Viennoiseries'),
      ];
      await ouvrir(tester);

      expect(find.text('Suggestions'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Grillades'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'grillades'), findsNothing);
      expect(find.text('Disponible maintenant'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Viennoiseries'));
      await tester.pump();
      await tester.pump();
      expect(depot.requetes, ['Viennoiseries']);
    },
  );

  testWidgets(
    'une recherche validée devient une recherche récente, effaçable',
    (tester) async {
      depot.resultat = _unPlat();
      await chercher(tester, 'poulet');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Recherches récentes'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'poulet'), findsOneWidget);

      await tester.tap(find.text('Effacer'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Recherches récentes'), findsNothing);
    },
  );

  testWidgets('succès : les plats trouvés s\'affichent', (tester) async {
    depot.resultat = _unPlat();
    await chercher(tester, 'poulet');
    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(depot.requetes, ['poulet']);
  });

  testWidgets('vide : un message nomme la recherche', (tester) async {
    await chercher(tester, 'xyz');
    expect(find.text('Aucun résultat pour « xyz »'), findsOneWidget);
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
