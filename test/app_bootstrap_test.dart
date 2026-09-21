// **Le test que l'absence des effets de session aurait dû faire échouer.**
//
// `session_effects_test.dart` monte `sessionEffectsProvider` lui-même. Il
// prouve que le coordinateur fonctionne — il ne prouve pas que l'application
// l'allume. C'est très exactement la nuance qui a coûté les deux P0 : le
// panier du visiteur était couvert par sept tests verts, tous appelant
// `adoptGuestCart()` à la main, pendant que rien ne le déclenchait.
//
// `boot_smoke_test.dart` ne peut pas le voir non plus : il monte un `_App` de
// trois lignes qui n'observe que le routeur. Une réplique n'attrape jamais
// « le vrai widget a oublié d'observer quelque chose ».
//
// Ici on monte **`MyApp`**, celui de `main.dart`, celui qui est compilé dans le
// binaire. Retirer `ref.watch(sessionEffectsProvider)` de `main.dart` fait
// échouer ce fichier, et lui seul.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/main.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/services/connectivity_service.dart';
import 'package:lilia_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/fake_auth_repository.dart';

class _OnboardingFait extends OnboardingStatus {
  @override
  Future<bool> build() async => true;
}

/// Compte ce que l'ouverture de session déclenche. Rien de plus.
class _FauxNotifications implements NotificationService {
  int enregistrements = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> registerTokenOnServer({int maxRetries = 5}) async =>
      enregistrements++;

  @override
  void forgetRegisteredToken() {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

class _FauxPanier implements CartRepository {
  int ajouts = 0;

  @override
  Future<Cart?> getCart() async => null;

  @override
  Future<Cart?> addToCart({
    required String variantId,
    required int quantity,
  }) async {
    ajouts++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

void main() {
  late FakeAuthRepository auth;
  late _FauxNotifications notifications;
  late StreamController<bool> reseau;

  /// Monte `MyApp` — le vrai — avec les seuls doubles indispensables.
  ///
  /// Tout ce qui est surchargé ici l'est pour **une** raison : le composant
  /// touche Firebase, un canal de plateforme ou le réseau, et rien de tout
  /// cela n'existe dans un test de widget. Aucun de ces doubles ne remplace
  /// une décision de l'application.
  Future<void> demarrerLApplication(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    auth = FakeAuthRepository();
    notifications = _FauxNotifications();
    reseau = StreamController<bool>.broadcast();
    addTearDown(reseau.close);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        onboardingStatusProvider.overrideWith(_OnboardingFait.new),
        // Analytics et Sentry veulent un Firebase initialisé.
        routerObserversProvider.overrideWithValue(const []),
        // `apiClientProvider` lit `FirebaseAuth.instance`, qui lève sans
        // `Firebase.initializeApp()`. Le client de test ne parle à personne.
        apiClientProvider.overrideWithValue(
          ApiClient.test(
            baseUrl: 'https://test.local',
            tokenProvider: () async => null,
            forceRefreshToken: () async => null,
          ),
        ),
        // Même motif : `firebaseIdTokenProvider` part de `FirebaseAuth.instance`.
        firebaseIdTokenProvider.overrideWith((ref) => Stream<String?>.value(null)),
        notificationServiceProvider.overrideWithValue(notifications),
        cartRepositoryProvider.overrideWithValue(_FauxPanier()),
        // `connectivity_plus` n'a pas de canal de plateforme sous le binding
        // de test.
        connectivityStatusProvider.overrideWith(
          (ref) async* {
            yield true;
            yield* reseau.stream;
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
  }

  /// Pompe sur un budget borné, en drainant les exceptions.
  ///
  /// ⚠️ Pas de `pumpAndSettle` : le carrousel de bannières de l'accueil
  /// s'auto-défile, l'arbre ne se stabilise jamais. Et les images en asset ne
  /// sont pas servies dans un bundle de test — leur échec de chargement n'a
  /// rien à voir avec ce qui est éprouvé ici.
  Future<void> laisserTourner(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      tester.takeException();
    }
  }

  /// Démonte et laisse retomber les minuteurs de l'accueil (chatoiement,
  /// carrousel, cache de listes) — sans quoi le binding refuse de rendre la
  /// main.
  Future<void> ranger(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 6));
    tester.takeException();
  }

  testWidgets(
    'MyApp allume les effets de session : une connexion enregistre le jeton',
    (tester) async {
      await demarrerLApplication(tester);
      await laisserTourner(tester);

      expect(
        notifications.enregistrements,
        0,
        reason: 'aucune session ouverte : rien à rattacher',
      );

      // La seule chose que fait ce test : ouvrir une session, comme Firebase
      // le ferait après un `signInWithEmailAndPassword`.
      auth.emitSession(const AppUser(uid: 'uid-a', email: 'a@lilia.cg'));
      await laisserTourner(tester);

      expect(
        notifications.enregistrements,
        1,
        reason:
            'sans `ref.watch(sessionEffectsProvider)` dans `MyApp`, le '
            'coordinateur n’est jamais construit et ce compteur reste à zéro',
      );

      await ranger(tester);
    },
  );

  testWidgets(
    'MyApp monte la grille de connectivité SOUS le ScaffoldMessenger',
    (tester) async {
      await demarrerLApplication(tester);
      await laisserTourner(tester);

      expect(find.text('Pas de connexion internet'), findsNothing);

      // Le réseau tombe. C'est tout ce que fait ce test.
      reseau.add(false);
      await laisserTourner(tester);

      // Montée au-dessus de `MaterialApp`, la grille appelait
      // `ScaffoldMessenger.of` depuis un contexte qui n'en a pas : l'appel
      // levait, à chaque bascule de réseau, au lieu d'afficher quoi que ce
      // soit. Ici, `laisserTourner` draine les exceptions — on vérifie donc
      // le résultat visible, qui est la seule preuve qui compte.
      expect(
        find.text('Pas de connexion internet'),
        findsWidgets,
        reason:
            'la bannière n’était montée nulle part, et le seul widget de '
            'connectivité que montait `main.dart` levait au lieu d’afficher',
      );

      reseau.add(true);
      await laisserTourner(tester);
      expect(find.text('Pas de connexion internet'), findsNothing);

      await ranger(tester);
    },
  );
}
