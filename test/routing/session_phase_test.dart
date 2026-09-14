// M-08 / U-03 — « pas encore résolu » n'est pas « déconnecté ».
//
// Le routeur ne lisait pas d'état de session : il lisait deux `AsyncValue` et
// en tirait un booléen. `data(null)` et « en chargement » se confondaient, d'où
// le flash de l'accueil au démarrage et le « Votre session a expiré » à froid.
// Ces tests verrouillent la distinction, y compris dans les cas où elle est
// tentante à perdre : erreur de stockage, rafraîchissement en cours de session.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/routing/session_phase.dart';

import '../features/auth/fake_auth_repository.dart';

const _cliente = AppUser(uid: 'uid-1', email: 'cliente@lilia.cg');

/// Onboarding piloté à la main : le vrai passe par SharedPreferences, dont la
/// résolution asynchrone rendrait la phase de bootstrap intestable.
class _FakeOnboarding extends OnboardingStatus {
  _FakeOnboarding(this._etat);
  final AsyncValue<bool> _etat;

  @override
  Future<bool> build() {
    // On force l'état directement : `build` n'est pas rappelé après.
    if (_etat is AsyncData<bool>) return Future.value(_etat.value);
    if (_etat is AsyncError) {
      return Future.error((_etat as AsyncError).error);
    }
    // Chargement perpétuel : c'est exactement l'état à éprouver.
    return Completer<bool>().future;
  }

  /// Le vrai passe par SharedPreferences, absent en test unitaire. Seul
  /// compte ici l'effet observable : la phase quitte `onboardingRequired`.
  @override
  Future<void> completeOnboarding() async => state = const AsyncData(true);
}

void main() {
  late FakeAuthRepository repo;

  ProviderContainer creerConteneur({
    required AsyncValue<bool> onboarding,
    AppUser? session,
    bool sessionResolue = true,
  }) {
    repo = FakeAuthRepository(user: session);
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        onboardingStatusProvider.overrideWith(() => _FakeOnboarding(onboarding)),
        if (!sessionResolue)
          authStateChangeProvider.overrideWith(
            (ref) => const Stream<AppUser?>.empty().asBroadcastStream(),
          ),
      ],
    );
    // ⚠️ Abonnement indispensable, et pas seulement décoratif : sans écouteur
    // actif, un `container.read` répété d'un provider `keepAlive` ne recalcule
    // pas quand ses dépendances changent — la phase resterait éternellement à
    // `bootstrapping` dans les tests. En production c'est `routerProvider` qui
    // tient cet abonnement (`ref.listen`), donc la situation ne se présente pas.
    c.listen(sessionPhaseProvider, (_, _) {}, fireImmediately: true);
    return c;
  }

  /// Laisse les providers asynchrones se résoudre.
  ///
  /// Le flux Firebase et l'onboarding se résolvent chacun en plusieurs
  /// microtâches (`Stream.multi` d'un côté, `build` asynchrone de l'autre) :
  /// on pompe jusqu'à ce que la phase se stabilise, plutôt que de parier sur
  /// un nombre de tours.
  Future<void> resoudre(ProviderContainer c) async {
    var precedente = c.read(sessionPhaseProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      final courante = c.read(sessionPhaseProvider);
      if (i > 2 && courante == precedente) return;
      precedente = courante;
    }
  }

  test('rien n’est résolu → BOOTSTRAPPING', () async {
    final c = creerConteneur(onboarding: const AsyncLoading());
    addTearDown(c.dispose);
    expect(c.read(sessionPhaseProvider), SessionPhase.bootstrapping);
  });

  test('onboarding résolu mais session pas encore → BOOTSTRAPPING', () async {
    final c = creerConteneur(
      onboarding: const AsyncData(true),
      sessionResolue: false,
    );
    addTearDown(c.dispose);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.bootstrapping);
  });

  test('session résolue mais onboarding pas encore → BOOTSTRAPPING', () async {
    final c = creerConteneur(
      onboarding: const AsyncLoading(),
      session: _cliente,
    );
    addTearDown(c.dispose);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.bootstrapping);
  });

  test('tout résolu, session ouverte → AUTHENTICATED', () async {
    final c = creerConteneur(
      onboarding: const AsyncData(true),
      session: _cliente,
    );
    addTearDown(c.dispose);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.authenticated);
  });

  test('tout résolu, aucune session → UNAUTHENTICATED', () async {
    final c = creerConteneur(onboarding: const AsyncData(true));
    addTearDown(c.dispose);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.unauthenticated);
  });

  test('onboarding jamais fait → ONBOARDING_REQUIRED', () async {
    final c = creerConteneur(onboarding: const AsyncData(false));
    addTearDown(c.dispose);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.onboardingRequired);
  });

  test(
    'une erreur de stockage local ne coince pas dans le bootstrap',
    () async {
      // Une panne de SharedPreferences ne doit pas enfermer le client dans un
      // écran de démarrage dont on ne sort jamais : on saute l'onboarding.
      final c = creerConteneur(
        onboarding: AsyncError(Exception('prefs HS'), StackTrace.empty),
      );
      addTearDown(c.dispose);
      await resoudre(c);
      expect(c.read(sessionPhaseProvider), SessionPhase.unauthenticated);
    },
  );

  test('la connexion fait basculer la phase', () async {
    final c = creerConteneur(onboarding: const AsyncData(true));
    addTearDown(c.dispose);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.unauthenticated);

    repo.emitSession(_cliente);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.authenticated);
  });

  test('la déconnexion fait rebasculer la phase', () async {
    final c = creerConteneur(
      onboarding: const AsyncData(true),
      session: _cliente,
    );
    addTearDown(c.dispose);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.authenticated);

    repo.emitSession(null);
    await resoudre(c);
    expect(c.read(sessionPhaseProvider), SessionPhase.unauthenticated);
  });

  test(
    'la fin de l’onboarding ne repasse jamais par le bootstrap',
    () async {
      // `hasValue || hasError` et non `!isLoading` : un provider qui se
      // rafraîchit repasse par `isLoading` en gardant sa valeur. Retomber en
      // bootstrap à ce moment-là renverrait le client sur l'écran de démarrage
      // au milieu de sa session.
      final c = creerConteneur(onboarding: const AsyncData(false));
      addTearDown(c.dispose);
      await resoudre(c);
      expect(c.read(sessionPhaseProvider), SessionPhase.onboardingRequired);

      await c.read(onboardingStatusProvider.notifier).completeOnboarding();
      await resoudre(c);
      expect(c.read(sessionPhaseProvider), SessionPhase.unauthenticated);
    },
  );
}
