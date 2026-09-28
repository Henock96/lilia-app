// Mesure : combien de fois le carrousel de l'accueil fait-il reconstruire la
// liste des vendeurs ?
//
// Le carrousel tourne toutes les 4 s. Son indicateur de page vivait dans le
// `State` de l'écran d'accueil : chaque page tournée faisait un `setState` sur
// l'écran entier, dont la liste des vendeurs (en `shrinkWrap`, donc
// intégralement reconstruite et remise en page).
//
// On compte les **instances** de `RestaurantCard` observées pendant 13 s
// d'auto-défilement : une reconstruction du parent en crée de nouvelles.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';
import 'package:lilia_app/features/favoris/application/restaurant_favorites_provider.dart';
import 'package:lilia_app/features/home/data/remote/banner_controller.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/presentation/home.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/restaurant_card.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/theme/app_theme.dart';

class _AucuneNotification extends NotificationHistory {
  @override
  Future<List<AppNotification>> build() async => [];
}

void main() {
  testWidgets('le carrousel ne reconstruit pas la liste des vendeurs', (
    tester,
  ) async {
    final vendeurs = [
      for (var i = 0; i < 30; i++)
        RestaurantSummary(id: 'r$i', name: 'Vendeur $i', address: 'Poto-Poto'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bannersListProvider.overrideWith((ref) async => []),
          vendorsListProvider.overrideWith((ref) async => vendeurs),
          popularProductsProvider.overrideWith((ref) async => []),
          recommendationsProvider.overrideWith((ref) async => []),
          notificationHistoryProvider.overrideWith(_AucuneNotification.new),
          isRestaurantFavoriteProvider.overrideWith((ref, id) => false),
          appUpdateInfoProvider.overrideWith(
            (ref) => Completer<AppUpdateInfo>().future,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    tester.takeException();

    final instances = <Widget>{};
    void observer() {
      for (final e in find.byType(RestaurantCard).evaluate()) {
        instances.add(e.widget);
      }
    }

    observer();
    final auDepart = instances.length;
    for (var t = 0; t < 130; t++) {
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      observer();
    }
    // ignore: avoid_print
    print(
      'MESURE cartes visibles=$auDepart instances après 13 s=${instances.length} '
      '→ reconstructions=${instances.length ~/ auDepart - 1}',
    );
    expect(instances.length, auDepart, reason: 'aucune reconstruction');
  });
}
