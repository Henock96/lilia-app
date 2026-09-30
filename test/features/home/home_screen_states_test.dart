// L'accueil face aux pannes de ses sources — sans désactiver la relance
// automatique de Riverpod 3, qui masquait chaque erreur ~38 s derrière un
// chargement.
//
// P1 — l'accueil doit rester utilisable quand l'API des bannières tombe.
//
// Le repli pointait vers `assets/images/banner.png`, fichier qui n'a jamais
// existé : la panne de l'API se doublait d'une erreur de chargement d'asset,
// précisément au moment où il fallait un repli fiable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';
import 'package:lilia_app/features/home/data/remote/banner_controller.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/home/data/remote/home_repo.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/home/presentation/widgets/section_skeleton.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/theme/app_theme.dart';

class _AucuneNotification extends NotificationHistory {
  @override
  Future<List<AppNotification>> build() async => [];
}

void main() {
  Future<void> monterAccueil(
    WidgetTester tester, {
    Future<List<Never>> Function()? bannieres,
    Future<List<RestaurantSummary>> Function()? vendeurs,
    Future<AvailableNow> Function()? disponibles,
    bool reduireAnimations = false,
    bool relanceAuto = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: relanceAuto ? null : (_, _) => null,
        overrides: [
          bannersListProvider.overrideWith(
            (ref) => bannieres?.call() ?? Future.value([]),
          ),
          vendorsListProvider.overrideWith(
            (ref) => vendeurs?.call() ?? Future.value([]),
          ),
          availableNowProvider.overrideWith(
            (ref) =>
                disponibles?.call() ??
                Future.value(const AvailableNow(products: [])),
          ),
          authStateChangeProvider.overrideWith((ref) => Stream.value(null)),
          recommendationsProvider.overrideWith((ref) async => []),
          notificationHistoryProvider.overrideWith(_AucuneNotification.new),
          // Jamais résolu : aucune invite de mise à jour dans ce test.
          appUpdateInfoProvider.overrideWith(
            (ref) => Completer<AppUpdateInfo>().future,
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduireAnimations),
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ),
      ),
    );
    // Budget borné : le carrousel s'auto-défile, l'arbre ne se stabilise
    // jamais (voir CLAUDE.md, « Ne pas utiliser pumpAndSettle »).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('API bannières en erreur : repli éditorial, aucun asset chargé', (
    tester,
  ) async {
    await monterAccueil(
      tester,
      bannieres: () => Future.error(Exception('503 Service Unavailable')),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Bienvenue sur Lilia Food'), findsWidgets);
    expect(find.textContaining('503'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is AssetImage),
      findsNothing,
      reason: 'le repli ne dépend d\'aucun fichier du bundle',
    );
  });

  testWidgets('liste vide : même repli', (tester) async {
    await monterAccueil(tester, bannieres: () async => []);
    expect(tester.takeException(), isNull);
    expect(find.text('Bienvenue sur Lilia Food'), findsWidgets);
  });

  testWidgets(
    'vendeurs en panne : message et Réessayer tout de suite, qui relance '
    'bien la liste affichée',
    (tester) async {
      var appels = 0;
      Object? panne = const ApiException(
        'Connexion impossible.',
        kind: ApiErrorKind.network,
      );
      await monterAccueil(
        tester,
        // Seul le bouton doit pouvoir relancer : la relance automatique
        // rétablissait la liste d'elle-même et masquait un bouton inopérant.
        relanceAuto: false,
        vendeurs: () async {
          appels++;
          if (panne != null) throw panne;
          return [];
        },
      );

      await tester.scrollUntilVisible(
        find.text('Réessayer'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Connexion impossible.'), findsOneWidget);

      panne = null;
      final avant = appels;
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Le bouton invalidait `restaurantsListProvider`, que l'écran n'observe
      // pas : il ne relançait rien.
      expect(appels, greaterThan(avant));
      expect(
        find.text('Aucune boutique disponible pour le moment'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    '« Disponible maintenant » en panne : ligne compacte, accueil intact',
    (tester) async {
      await monterAccueil(
        tester,
        relanceAuto: false,
        disponibles: () => Future.error(
          const ApiException('Indisponible.', kind: ApiErrorKind.server),
        ),
      );
      expect(find.text('Disponible maintenant'), findsOneWidget);
      expect(
        find.text('Impossible de charger les disponibilités.'),
        findsOneWidget,
      );
      // L'erreur brute du serveur n'est jamais affichée.
      expect(find.text('Indisponible.'), findsNothing);
      // Le reste de l'accueil vit sa vie.
      expect(find.text('Toutes les boutiques'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('« Disponible maintenant » en chargement : titre + squelette', (
    tester,
  ) async {
    await monterAccueil(
      tester,
      disponibles: () => Completer<AvailableNow>().future,
    );
    expect(find.text('Disponible maintenant'), findsOneWidget);
    expect(find.byType(RailSkeleton), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
