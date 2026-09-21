// **Se déconnecter n'est pas se faire déconnecter.**
//
// Les deux ferment la session, mais ils ne veulent pas dire la même chose :
//
//   session EXPIRÉE  → « vous alliez là, reconnectez-vous » → /signin?from=…
//   déconnexion VOULUE → « je pars »                        → /
//
// `resolveRedirect` ne connaît que le premier cas : un visiteur sur un
// emplacement protégé est renvoyé vers la connexion, avec la destination en
// mémoire. Appliquée à une déconnexion demandée depuis `/profile`, la règle
// présentait un écran de connexion à quelqu'un qui venait de dire qu'il
// partait.
//
// Le correctif n'est pas une exception dans le garde — ce serait lui faire
// porter une intention qu'il ne peut pas connaître — mais un **ordre** :
// quitter la zone protégée, puis fermer la session.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/utils/provider_cache.dart';

import '../features/auth/fake_auth_repository.dart';

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

void main() {
  late FakeAuthRepository auth;
  late GoRouter routeur;

  Future<void> avancer(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      tester.takeException();
    }
  }

  Future<void> demarrer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    auth = FakeAuthRepository(user: const AppUser(uid: 'uid-a'));
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        onboardingStatusProvider.overrideWith(_OnboardingFait.new),
        routerObserversProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    // `listen` et non `read` : sans auditeur, Riverpod 3 met le provider en
    // pause et l'application ne quitte jamais l'écran de démarrage.
    addTearDown(container.listen(routerProvider, (_, _) {}).close);
    routeur = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: routeur),
      ),
    );
    await avancer(tester, 40);
  }

  Future<void> ranger(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(kCatalogCacheTtl);
    tester.takeException();
  }

  String emplacement() =>
      routeur.routerDelegate.currentConfiguration.uri.toString();

  testWidgets(
    'déconnexion VOULUE depuis le profil : on arrive sur l’accueil',
    (tester) async {
      await demarrer(tester);
      routeur.go(AppRoutes.profile.path);
      await avancer(tester);
      expect(emplacement(), AppRoutes.profile.path);

      // Ce que fait le bouton « Déconnecter » : naviguer, PUIS fermer.
      routeur.goNamed(AppRoutes.home.routeName);
      await auth.signOut();
      await avancer(tester);

      expect(
        emplacement(),
        AppRoutes.home.path,
        reason:
            'dans l’ordre inverse, le garde voyait un visiteur sur /profile '
            'et renvoyait vers /signin?from=%2Fprofile',
      );
      expect(emplacement(), isNot(contains('signin')));

      await ranger(tester);
    },
  );

  testWidgets(
    'l’ordre inverse produit bien le défaut — la raison du correctif',
    (tester) async {
      await demarrer(tester);
      routeur.go(AppRoutes.profile.path);
      await avancer(tester);

      // On ferme la session SANS quitter la zone protégée au préalable.
      await auth.signOut();
      await avancer(tester);

      expect(
        emplacement(),
        contains('signin'),
        reason:
            'ce test documente le comportement du garde, qui reste juste pour '
            'une session expirée : c’est l’ordre des gestes qui distingue les '
            'deux intentions, pas une exception dans la règle',
      );

      await ranger(tester);
    },
  );

  testWidgets(
    'une session EXPIRÉE continue de mener à la connexion, avec sa destination',
    (tester) async {
      await demarrer(tester);
      routeur.go('/commandes/cmd-1');
      await avancer(tester);

      // Jeton révoqué côté serveur : `SessionGuard` ferme la session sans que
      // le client ait rien demandé.
      await auth.signOut();
      await avancer(tester);

      expect(emplacement(), contains('signin'));
      expect(
        emplacement(),
        contains('from='),
        reason:
            'R-05 : le client renvoyé au login doit retrouver sa commande '
            'après s’être reconnecté',
      );

      await ranger(tester);
    },
  );
}
