// UI Refresh (C8) — l'accueil montre d'abord ce qui se commande MAINTENANT.
//
// Accueil réel (`HomeScreen`) et vrai `availableNowProvider` : seul le dépôt
// est remplacé, pour vérifier aussi ce qui part au serveur (`vendorType`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/home/data/remote/banner_controller.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/data/remote/home_repo.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/home/presentation/widgets/open_now_rail.dart';
import 'package:lilia_app/features/home/presentation/widgets/product_rail_card.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/theme/app_theme.dart';

class _AucuneNotification extends NotificationHistory {
  @override
  Future<List<AppNotification>> build() async => [];
}

const _horsLigne = ApiException(
  'Connexion impossible.',
  kind: ApiErrorKind.network,
);

/// Dépôt d'accueil piloté par le test ; retient les filtres demandés.
class _Depot implements HomeRepository {
  List<Product> produits = const [];
  bool enLigne = true;
  final List<VendorType?> filtresDemandes = [];

  @override
  Future<AvailableNow> getAvailableNow({
    VendorType? vendorType,
    int limit = 10,
  }) async {
    filtresDemandes.add(vendorType);
    if (!enLigne) throw _horsLigne;
    return AvailableNow(
      products: produits,
      generatedAt: DateTime.now(),
      vendorType: vendorType,
    );
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Product _plat(String nom, {String vendeur = 'Chez Awa', int? orderCount}) =>
    Product(
      id: nom,
      name: nom,
      description: '',
      prixOriginal: 3500,
      restaurantId: 'v',
      restaurantName: vendeur,
      restaurantIsOpen: true,
      isAvailable: true,
      orderCount: orderCount,
      variants: [ProductVariant(id: '$nom-v', label: 'Normal', prix: 3500)],
    );

RestaurantSummary _vendeur(
  String id, {
  bool? isOpen = true,
  DateTime? nextOpeningAt,
  bool served = true,
}) => RestaurantSummary(
  id: id,
  name: id,
  address: 'Brazzaville',
  isOpen: isOpen,
  nextOpeningAt: nextOpeningAt,
  nextOpeningServed: served,
);

void main() {
  late _Depot depot;
  late List<RestaurantSummary> vendeurs;
  late bool vendeursEnLigne;
  Completer<List<RestaurantSummary>>? boulangeries;

  setUp(() {
    depot = _Depot();
    vendeurs = [];
    vendeursEnLigne = true;
    boulangeries = null;
  });

  Future<ProviderContainer> monter(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          homeRepositoryProvider.overrideWithValue(depot),
          bannersListProvider.overrideWith((ref) async => []),
          authStateChangeProvider.overrideWith((ref) => Stream.value(null)),
          vendorsListProvider.overrideWith((ref) async {
            final filtre = ref.watch(marketplaceFilterProvider);
            if (!vendeursEnLigne) throw _horsLigne;
            if (filtre == VendorType.BAKERY && boulangeries != null) {
              return boulangeries!.future;
            }
            return vendeurs;
          }),
          notificationHistoryProvider.overrideWith(_AucuneNotification.new),
          appUpdateInfoProvider.overrideWith(
            (ref) => Completer<AppUpdateInfo>().future,
          ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
    await _pomper(tester);
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  Future<void> demonter(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Finder dansOuvert(String t) =>
      find.descendant(of: find.byType(OpenNowRail), matching: find.text(t));

  testWidgets(
    'ordre : filtres, ouvert, disponible, puis toutes les boutiques',
    (tester) async {
      vendeurs = [_vendeur('Chez Awa')];
      depot.produits = [_plat('Saka-saka')];
      await monter(tester);

      double y(Finder f) => tester.getTopLeft(f).dy;
      final ouvert = y(find.textContaining('Ouvert maintenant'));
      final dispo = y(find.text('Disponible maintenant'));
      final toutes = y(find.text('Toutes les boutiques'));
      expect(ouvert < dispo && dispo < toutes, isTrue);
      await demonter(tester);
    },
  );

  testWidgets('vendeur ouvert : dans « Ouvert maintenant » ; fermé : non', (
    tester,
  ) async {
    vendeurs = [_vendeur('Chez Awa'), _vendeur('Chez Lili', isOpen: false)];
    await monter(tester);
    expect(dansOuvert('Chez Awa'), findsOneWidget);
    expect(dansOuvert('Chez Lili'), findsNothing);
    expect(find.text('Ouvert maintenant · 1'), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('aucun vendeur ouvert : la section disparaît', (tester) async {
    vendeurs = [_vendeur('Chez Lili', isOpen: false)];
    await monter(tester);
    expect(find.textContaining('Ouvert maintenant'), findsNothing);
    await demonter(tester);
  });

  testWidgets('TEST CRITIQUE — isOpen null : jamais « Ouvert »', (
    tester,
  ) async {
    vendeurs = [_vendeur('Inconnu', isOpen: null)];
    await monter(tester);
    expect(find.textContaining('Ouvert maintenant'), findsNothing);
    final carte = find.byType(RestaurantCard);
    expect(
      find.descendant(of: carte, matching: find.text('Ouvert')),
      findsNothing,
    );
    expect(
      find.descendant(of: carte, matching: find.text('Horaires indisponibles')),
      findsOneWidget,
    );
    await demonter(tester);
  });

  testWidgets('TEST CRITIQUE — fermé sans nextOpeningAt : « Fermé » seul', (
    tester,
  ) async {
    vendeurs = [_vendeur('Chez Lili', isOpen: false)];
    await monter(tester);
    final carte = find.byType(RestaurantCard);
    expect(
      find.descendant(of: carte, matching: find.text('Fermé')),
      findsOneWidget,
    );
    expect(find.textContaining('ouvre à'), findsNothing);
    await demonter(tester);
  });

  testWidgets('fermé avec nextOpeningAt : l’heure servie sur la carte', (
    tester,
  ) async {
    final demain10h = _demainA10h();
    vendeurs = [_vendeur('Chez Lili', isOpen: false, nextOpeningAt: demain10h)];
    await monter(tester);
    final badge = find.descendant(
      of: find.byType(RestaurantCard),
      matching: find.text('Fermé — demain à 10h00'),
    );
    expect(badge, findsOneWidget);
    // Vendeur sans photo : le placeholder sans largeur réduisait la pile, et
    // le badge (borné à droite) tombait à zéro — présent mais invisible.
    expect(tester.getSize(badge).width, greaterThan(100));
    expect(
      tester.getSize(find.byType(RestaurantCard)).width -
          tester.getTopLeft(badge).dx,
      greaterThan(150),
    );
    await demonter(tester);
  });

  testWidgets('produits disponibles : le rail, sans compteur de ventes', (
    tester,
  ) async {
    vendeurs = [_vendeur('Chez Awa')];
    depot.produits = [_plat('Saka-saka', orderCount: 80), _plat('Poulet DG')];
    await monter(tester);
    expect(find.byType(ProductRailCard), findsNWidgets(2));
    expect(find.textContaining('fois'), findsNothing);
    expect(find.textContaining('populaire'), findsNothing);
    await demonter(tester);
  });

  testWidgets('aucun produit, tout fermé, réouvertures servies : les heures', (
    tester,
  ) async {
    final demain10h = _demainA10h();
    vendeurs = [
      _vendeur(
        'Plus tard',
        isOpen: false,
        nextOpeningAt: demain10h.add(const Duration(hours: 2)),
      ),
      _vendeur('Chez Lili', isOpen: false, nextOpeningAt: demain10h),
      _vendeur('Sans heure', isOpen: false),
    ];
    await monter(tester);
    expect(find.text('Les boutiques rouvrent bientôt'), findsOneWidget);
    // Triées, la plus proche d'abord ; le vendeur sans heure n'y figure pas.
    final lili = find.textContaining('Chez Lili · demain à 10h00');
    final tard = find.textContaining('Plus tard · demain à 12h00');
    expect(lili, findsOneWidget);
    expect(tard, findsOneWidget);
    expect(tester.getTopLeft(lili).dy < tester.getTopLeft(tard).dy, isTrue);
    expect(find.textContaining('Sans heure ·'), findsNothing);
    await demonter(tester);
  });

  testWidgets('aucun produit, aucune heure connue : rien d’inventé', (
    tester,
  ) async {
    vendeurs = [_vendeur('Chez Lili', isOpen: false)];
    await monter(tester);
    expect(find.text('Les boutiques rouvrent bientôt'), findsNothing);
    expect(
      find.text('Les boutiques sont fermées pour le moment.'),
      findsOneWidget,
    );
    expect(find.textContaining('ouvre à'), findsNothing);
    expect(find.text('Voir toutes les boutiques'), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('aucun produit mais une boutique ouverte : pas de « rouvrent »', (
    tester,
  ) async {
    vendeurs = [
      _vendeur('Chez Awa'),
      _vendeur('Chez Lili', isOpen: false, nextOpeningAt: _demainA10h()),
    ];
    await monter(tester);
    expect(find.text('Les boutiques rouvrent bientôt'), findsNothing);
    expect(
      find.textContaining('Aucun produit n’est disponible'),
      findsOneWidget,
    );
    await demonter(tester);
  });

  testWidgets('le filtre de type part au serveur', (tester) async {
    final c = await monter(tester);
    expect(depot.filtresDemandes, [null]);
    c.read(marketplaceFilterProvider.notifier).set(VendorType.BAKERY);
    await _pomper(tester);
    expect(depot.filtresDemandes.last, VendorType.BAKERY);
    await demonter(tester);
  });

  testWidgets('hors ligne avec liste : conservée, atténuée, « à vérifier »', (
    tester,
  ) async {
    vendeurs = [_vendeur('Chez Awa')];
    depot.produits = [_plat('Saka-saka')];
    final c = await monter(tester);

    depot.enLigne = false;
    c.invalidate(availableNowProvider);
    await _pomper(tester);

    expect(find.byType(ProductRailCard), findsOneWidget);
    expect(
      find.textContaining('Disponibilités à vérifier (hors ligne)'),
      findsOneWidget,
    );
    await demonter(tester);
  });

  testWidgets('hors ligne sans liste : message compact, accueil intact', (
    tester,
  ) async {
    vendeurs = [_vendeur('Chez Awa')];
    depot.enLigne = false;
    await monter(tester);
    expect(
      find.text('Hors ligne : disponibilités non chargées.'),
      findsOneWidget,
    );
    expect(find.byType(RestaurantCard), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('changement de filtre raté hors ligne : pas la liste d’un '
      'autre filtre', (tester) async {
    depot.produits = [_plat('Saka-saka')];
    final c = await monter(tester);
    expect(find.byType(ProductRailCard), findsOneWidget);

    depot.enLigne = false;
    c.read(marketplaceFilterProvider.notifier).set(VendorType.BAKERY);
    await _pomper(tester);

    expect(find.byType(ProductRailCard), findsNothing);
    expect(
      find.text('Hors ligne : disponibilités non chargées.'),
      findsOneWidget,
    );
    await demonter(tester);
  });

  testWidgets('rechargement hors ligne : « Ouvert maintenant » garde sa '
      'liste', (tester) async {
    vendeurs = [_vendeur('Chez Awa')];
    final c = await monter(tester);
    expect(dansOuvert('Chez Awa'), findsOneWidget);

    vendeursEnLigne = false;
    c.invalidate(vendorsListProvider);
    await tester.pump();
    expect(dansOuvert('Chez Awa'), findsOneWidget, reason: 'en rechargement');
    await _pomper(tester);
    expect(dansOuvert('Chez Awa'), findsOneWidget, reason: 'après l’échec');
    await demonter(tester);
  });

  testWidgets('changement de filtre en cours : jamais les ouverts d’un autre '
      'filtre', (tester) async {
    vendeurs = [_vendeur('Chez Awa')];
    boulangeries = Completer();
    final c = await monter(tester);
    expect(dansOuvert('Chez Awa'), findsOneWidget);

    c.read(marketplaceFilterProvider.notifier).set(VendorType.BAKERY);
    await _pomper(tester);
    expect(dansOuvert('Chez Awa'), findsNothing);
    boulangeries!.complete([]);
    await demonter(tester);
  });

  testWidgets('thème sombre : aucun débordement ni exception', (tester) async {
    vendeurs = [
      _vendeur('Chez Awa'),
      _vendeur('Chez Lili', isOpen: false, nextOpeningAt: _demainA10h()),
    ];
    depot.produits = [_plat('Saka-saka')];
    await monter(tester, theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
    await demonter(tester);
  });
}

/// Demain 10h00 à Brazzaville (UTC+1), quelle que soit l'heure du test.
DateTime _demainA10h() {
  final bzv = DateTime.now().toUtc().add(const Duration(hours: 1));
  return DateTime.utc(bzv.year, bzv.month, bzv.day + 1, 9);
}

/// Budget borné : le carrousel de bannières défile seul.
Future<void> _pomper(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
