// P3-12 — une coupure réseau ne vide plus l'accueil.
//
// Riverpod garde la dernière valeur dans l'erreur d'un rechargement raté ;
// l'écran l'effaçait pour afficher l'erreur (« 0 disponibles »). On garde la
// liste, datée, et on ne la présente pas comme à jour.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/home/data/remote/home_repo.dart';
import 'package:lilia_app/common_widgets/stale_data_banner.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';
import 'package:lilia_app/features/home/data/remote/banner_controller.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
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

void main() {
  late bool enLigne;

  Future<ProviderContainer> monter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          bannersListProvider.overrideWith((ref) async => []),
          availableNowProvider.overrideWith(
            (ref) async => const AvailableNow(products: []),
          ),
          authStateChangeProvider.overrideWith((ref) => Stream.value(null)),
          recommendationsProvider.overrideWith((ref) async => []),
          vendorsListProvider.overrideWith((ref) async {
            final filtre = ref.watch(marketplaceFilterProvider);
            if (!enLigne) throw _horsLigne;
            return [
              RestaurantSummary(
                id: 'r1',
                name: filtre == null ? 'Chez Awa' : 'Boulangerie du Plateau',
                address: 'Poto-Poto',
              ),
            ];
          }),
          notificationHistoryProvider.overrideWith(_AucuneNotification.new),
          appUpdateInfoProvider.overrideWith(
            (ref) => Completer<AppUpdateInfo>().future,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await _pomper(tester);
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  testWidgets('coupure puis rechargement raté : la liste reste, datée', (
    tester,
  ) async {
    enLigne = true;
    final c = await monter(tester);
    expect(_dansLaListe('Chez Awa'), findsOneWidget);

    enLigne = false;
    c.invalidate(vendorsListProvider);
    await _pomper(tester);

    expect(_dansLaListe('Chez Awa'), findsOneWidget, reason: 'liste conservée');
    expect(find.byType(StaleDataBanner), findsOneWidget);
    expect(find.textContaining('Hors ligne — liste chargée à'), findsOneWidget);
    expect(find.textContaining('vérifiés à la commande'), findsOneWidget);
    expect(find.text('1 affiché'), findsOneWidget);

    // Retour du réseau + « Réessayer » : le bandeau disparaît.
    enLigne = true;
    await tester.tap(find.text('Réessayer'));
    await _pomper(tester);
    expect(find.byType(StaleDataBanner), findsNothing);
    expect(_dansLaListe('Chez Awa'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changement de filtre raté hors ligne : pas la liste d\'un '
      'autre filtre sous le nouveau titre', (tester) async {
    enLigne = true;
    final c = await monter(tester);
    expect(_dansLaListe('Chez Awa'), findsOneWidget);

    enLigne = false;
    c.read(marketplaceFilterProvider.notifier).set(VendorType.BAKERY);
    await _pomper(tester);

    expect(_dansLaListe('Chez Awa'), findsNothing);
    expect(find.byType(StaleDataBanner), findsNothing);
    expect(find.text('Connexion impossible.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('premier chargement hors ligne : erreur et Réessayer, pas '
      '« 0 disponibles »', (tester) async {
    enLigne = false;
    await monter(tester);
    expect(find.text('Connexion impossible.'), findsOneWidget);
    expect(find.textContaining('0 disponibles'), findsNothing);
    expect(find.byType(StaleDataBanner), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _pomper(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Carte de « Toutes les boutiques » : un vendeur ouvert figure aussi dans
/// « Ouvert maintenant », au-dessus.
Finder _dansLaListe(String nom) => find.descendant(
  of: find.byType(RestaurantCard),
  matching: find.text(nom),
);
