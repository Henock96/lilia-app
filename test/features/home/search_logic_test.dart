// Recherche : rangement des résultats, suggestions, historique par compte.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/home/application/recent_searches_provider.dart';
import 'package:lilia_app/features/home/domain/search_sections.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/search_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/fake_auth_repository.dart';

Product _plat(
  String id, {
  bool? ouverte = true,
  List<ProductVariant>? formats,
  String? categorie,
}) => Product(
  id: id,
  name: 'Plat $id',
  description: '',
  prixOriginal: 1000,
  imageUrl: null,
  restaurantId: 'r1',
  restaurantIsOpen: ouverte,
  categoryId: null,
  category: categorie == null ? null : Category(id: 'c-$id', name: categorie),
  isAvailable: true,
  variants: formats ?? [ProductVariant(id: 'v-$id', prix: 1000)],
);

void main() {
  group('Product.unavailability — verdict par format (F3-10)', () {
    test('stock restant mais aucun format vendable : épuisé', () {
      final p = _plat(
        'a',
        formats: [
          ProductVariant(id: 'v1', prix: 1, stockStatus: 'OUT_OF_STOCK'),
          ProductVariant(id: 'v2', prix: 2, stockStatus: 'OUT_OF_STOCK'),
        ],
      );
      expect(p.unavailability, ProductUnavailability.epuise);
    });

    test('un seul format encore vendable : commandable', () {
      final p = _plat(
        'a',
        formats: [
          ProductVariant(id: 'v1', prix: 1, stockStatus: 'OUT_OF_STOCK'),
          ProductVariant(id: 'v2', prix: 2, stockStatus: 'LOW'),
        ],
      );
      expect(p.isOrderable, isTrue);
    });

    test('sans verdict serveur (endpoint ancien) : rien n’est déduit', () {
      expect(_plat('a').isOrderable, isTrue);
    });
  });

  group('SearchSections', () {
    test('sépare commandables et non commandables, ordre serveur conservé', () {
      final s = SearchSections.from(
        SearchResult(
          restaurants: [],
          products: [
            _plat('1', ouverte: false),
            _plat('2'),
            _plat('3', ouverte: false),
            _plat('4'),
          ],
        ),
      );
      expect(s.orderableProducts.map((p) => p.id), ['2', '4']);
      expect(s.unavailableProducts.map((p) => p.id), ['1', '3']);
      expect(s.total, 4);
    });

    test('suggestions : catégories sans doublon (casse ignorée), bornées', () {
      final out = searchSuggestionsFrom([
        _plat('1', categorie: 'Grillades'),
        _plat('2', categorie: 'GRILLADES'),
        _plat('3'),
        _plat('4', categorie: '  '),
        _plat('5', categorie: 'Pâtisseries'),
        _plat('6', categorie: 'Jus'),
      ], max: 2);
      expect(out, ['Grillades', 'Pâtisseries']);
    });
  });

  group('RecentSearches', () {
    ProviderContainer conteneur(String uid) {
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: AppUser(uid: uid)),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(recentSearchesProvider, (_, _) {});
      return c;
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('plus récente en tête, doublon remonté, bornée', () async {
      final c = conteneur('uid-a');
      final n = c.read(recentSearchesProvider.notifier);
      await c.read(recentSearchesProvider.future);
      await n.add('poulet');
      await n.add('pizza');
      await n.add('Poulet');
      expect(await c.read(recentSearchesProvider.future), ['Poulet', 'pizza']);

      for (var i = 0; i < 12; i++) {
        await n.add('mot $i');
      }
      expect(
        (await c.read(recentSearchesProvider.future)).length,
        kRecentSearchesMax,
      );
    });

    test('une lettre n’est pas mémorisée', () async {
      final c = conteneur('uid-a');
      await c.read(recentSearchesProvider.future);
      await c.read(recentSearchesProvider.notifier).add('p');
      expect(await c.read(recentSearchesProvider.future), isEmpty);
    });

    test('un autre compte ne voit pas l’historique du précédent', () async {
      final a = conteneur('uid-a');
      await a.read(recentSearchesProvider.future);
      await a.read(recentSearchesProvider.notifier).add('gâteau');

      final b = conteneur('uid-b');
      expect(await b.read(recentSearchesProvider.future), isEmpty);
    });
  });
}
