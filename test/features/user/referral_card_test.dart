// La carte de parrainage ne disparaît pas sans un mot.
//
// Audit du 05/11/2026 : sur erreur, elle rendait `SizedBox.shrink()`. Le client
// perdait son code de parrainage de l'écran, sans message ni moyen de le
// retrouver.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/user/user_page.dart';
import 'package:lilia_app/models/loyalty_transaction.dart';

import '../auth/fake_auth_repository.dart';

const _reglages = PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 5,
  referrerBonusPoints: 3,
);

final _indisponible = find.textContaining('Parrainage indisponible');

Future<void> _ouvrir(
  WidgetTester tester,
  Future<ReferralStats> Function() lecture,
) async {
  tester.view
    ..physicalSize = const Size(1200, 5000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // Sinon la relance rétablit l'écran seule, et un « Réessayer » branché
      // sur le mauvais provider passerait quand même.
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userProfileProvider.overrideWith(
          (ref) async => const AppUser(uid: 'uid-a', nom: 'Awa'),
        ),
        referralStatsProvider.overrideWith((ref) => lecture()),
        loyaltyTransactionsProvider.overrideWith((ref) async => const []),
        platformSettingsProvider.overrideWith((ref) async => _reglages),
      ],
      child: const MaterialApp(home: UserPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('lecture ratée : le dit, et propose de réessayer', (tester) async {
    await _ouvrir(
      tester,
      () async => throw const ApiException('panne', statusCode: 500),
    );

    expect(_indisponible, findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('« Réessayer » relit les chiffres du parrainage', (tester) async {
    var lectures = 0;
    await _ouvrir(tester, () async {
      if (++lectures == 1) throw const ApiException('panne', statusCode: 500);
      return ReferralStats(
        referralCode: 'AWA42',
        totalReferrals: 1,
        rewardedReferrals: 0,
        loyaltyPoints: 3,
      );
    });

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump();

    expect(lectures, 2);
    expect(_indisponible, findsNothing);
    expect(find.text('AWA42'), findsOneWidget);
  });
}
