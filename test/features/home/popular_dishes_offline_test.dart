// Phase 3.7 — « Plats populaires » disparaissait hors ligne au lieu de garder
// sa dernière valeur. Même règle que la liste des vendeurs (P3-12) : la liste
// conservée reste, datée, jamais présentée comme à jour ; sans liste
// antérieure, rien n'est inventé.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/stale_data_banner.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/presentation/widgets/popular_dishes_section.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/theme/app_theme.dart';

import '../../helpers/real_fonts.dart';

const _horsLigne = ApiException(
  'Connexion impossible.',
  kind: ApiErrorKind.network,
);

Product _plat(String id, String nom) => Product(
  id: id,
  name: nom,
  description: '',
  prixOriginal: 3000,
  imageUrl: null,
  restaurantId: 'r1',
  restaurantName: 'Chez Awa',
  categoryId: null,
  isAvailable: true,
  variants: [ProductVariant(id: 'v-$id', label: 'Normal', prix: 3000)],
);

void main() {
  setUpAll(chargerPolicesReelles);

  late bool enLigne;
  late List<Product> catalogue;

  Future<ProviderContainer> monter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          popularProductsProvider.overrideWith((ref) async {
            if (!enLigne) throw _horsLigne;
            return catalogue;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: PopularDishesSection()),
          ),
        ),
      ),
    );
    await _pomper(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(PopularDishesSection)),
    );
  }

  setUp(() {
    enLigne = true;
    catalogue = [_plat('p1', 'Saka-saka'), _plat('p2', 'Poulet moambé')];
  });

  testWidgets('coupure puis rechargement raté : la liste reste, datée', (
    tester,
  ) async {
    final c = await monter(tester);
    expect(find.text('Saka-saka'), findsOneWidget);
    expect(find.byType(StaleDataBanner), findsNothing);

    enLigne = false;
    c.invalidate(popularProductsProvider);
    await _pomper(tester);

    expect(find.text('Plats Populaires'), findsOneWidget);
    expect(find.text('Saka-saka'), findsOneWidget, reason: 'liste conservée');
    expect(find.byType(StaleDataBanner), findsOneWidget);
    expect(find.textContaining('Hors ligne — liste chargée à'), findsOneWidget);
    expect(find.textContaining('vérifiés à la commande'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Retour du réseau + « Réessayer » : la liste fraîche, sans bandeau.
    enLigne = true;
    catalogue = [_plat('p3', 'Pondu')];
    await tester.tap(find.text('Réessayer'));
    await _pomper(tester);
    expect(find.byType(StaleDataBanner), findsNothing);
    expect(find.text('Pondu'), findsOneWidget);
    expect(find.text('Saka-saka'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('premier chargement hors ligne : rien d’inventé', (tester) async {
    enLigne = false;
    await monter(tester);

    expect(find.text('Plats Populaires'), findsNothing);
    expect(find.byType(StaleDataBanner), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dernière liste vide : pas de section conservée', (tester) async {
    catalogue = [];
    final c = await monter(tester);
    expect(find.text('Plats Populaires'), findsNothing);

    enLigne = false;
    c.invalidate(popularProductsProvider);
    await _pomper(tester);

    expect(find.text('Plats Populaires'), findsNothing);
    expect(find.byType(StaleDataBanner), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _pomper(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
