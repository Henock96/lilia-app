// Suppression d'un compte ouvert avec Apple — l'ordre des opérations.
//
// Exigence App Store (5.1.1(v)) : supprimer un compte « Sign in with Apple »
// doit révoquer l'autorisation Apple. Elle exige un jeton Firebase encore
// valide, donc un compte qui existe encore : la révocation doit précéder
// **tout** effacement. Et si le client ferme la feuille Apple, ou si la
// vérification échoue, **rien** ne doit être supprimé.
//
// Ces tests font tourner le **vrai** `AuthController.deleteAccount` ; le dépôt
// d'authentification, le dépôt utilisateur et le service de notifications sont
// doublés, et tous écrivent dans le même journal ordonné.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/user/data/user_repository.dart';
import 'package:lilia_app/services/notification_service.dart';

import 'fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;
  Object? refusServeur;

  setUp(() {
    refusServeur = null;
    repo = FakeAuthRepository(
      user: const AppUser(uid: 'uid-1', email: 'client@exemple.cg'),
    );
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(
          _UserRepoTemoin(repo.journal, () => refusServeur),
        ),
        notificationServiceProvider.overrideWithValue(
          _NotificationsTemoin(repo.journal),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<AuthFailure?> supprimer() =>
      container.read(authControllerProvider.notifier).deleteAccount();

  group('compte Apple', () {
    setUp(() => repo.lieAApple = true);

    test('ré-authentification et révocation Apple AVANT tout effacement',
        () async {
      final echec = await supprimer();

      expect(echec, isNull);
      expect(repo.journal, [
        'reauth-apple',
        'revoke-apple',
        'delete-backend',
        'forget-fcm',
        'delete-firebase',
      ]);
    });

    test('feuille Apple fermée : rien n’est supprimé, aucun message', () async {
      repo.revokeAppleError = FirebaseAuthException(code: 'canceled');

      final echec = await supprimer();

      expect(echec?.isSilent, isTrue);
      expect(repo.journal, ['reauth-apple'],
          reason: 'ni le jeton FCM, ni le backend, ni Firebase');
      expect(repo.currentUser, isNotNull, reason: 'la session reste ouverte');
    });

    test('vérification Apple échouée : rien n’est supprimé, et le message '
        'le dit', () async {
      repo.revokeAppleError = kAuthAppleVerificationFailed;

      final echec = await supprimer();

      expect(echec, kAuthAppleVerificationFailed);
      expect(echec!.message, contains('pas été supprimé'));
      expect(repo.journal, ['reauth-apple']);
    });

    test('réseau coupé pendant la vérification : rien n’est supprimé',
        () async {
      repo.revokeAppleError =
          FirebaseAuthException(code: 'network-request-failed');

      final echec = await supprimer();

      expect(echec?.kind, AuthFailureKind.network);
      expect(repo.journal, ['reauth-apple']);
    });

    test('refus du serveur (409) après révocation : le compte Firebase est '
        'conservé, le message du serveur remonte', () async {
      refusServeur = const ApiException(
        'Vous avez 1 commande(s) en cours.',
        kind: ApiErrorKind.client,
        statusCode: 409,
      );

      final echec = await supprimer();

      expect(echec?.message, 'Vous avez 1 commande(s) en cours.');
      expect(repo.journal, isNot(contains('delete-firebase')));
      // C-09 : le jeton FCM n'a pas été touché — le client garde les
      // notifications de la commande qui a bloqué la suppression.
      expect(repo.journal, isNot(contains('remove-fcm')));
      expect(repo.journal, isNot(contains('forget-fcm')));
    });
  });

  group('comptes sans Apple — comportement inchangé', () {
    // `lieAApple = false` : c'est le cas d'un compte Google ou e-mail. Le
    // vrai dépôt lit `providerData` ; son test dédié couvre cette décision.
    test('aucune ré-authentification, aucune révocation Apple', () async {
      final echec = await supprimer();

      expect(echec, isNull);
      expect(
        repo.journal,
        ['delete-backend', 'forget-fcm', 'delete-firebase'],
      );
    });
  });
}

class _UserRepoTemoin extends UserRepository {
  _UserRepoTemoin(this.journal, this.refus)
      : super(
          ApiClient(
            baseUrl: 'https://api.test',
            tokenProvider: () async => 'jeton',
            forceRefreshToken: () async => 'jeton',
          ),
        );

  final List<String> journal;
  final Object? Function() refus;

  @override
  Future<void> deleteAccount() async {
    final r = refus();
    if (r != null) throw r;
    journal.add('delete-backend');
  }
}

/// Seuls `removeTokenFromServer` et `forgetRegisteredToken` sont attendus. Tout autre appel échoue
/// bruyamment plutôt que de passer pour un succès.
class _NotificationsTemoin implements NotificationService {
  _NotificationsTemoin(this.journal);

  final List<String> journal;

  @override
  Future<void> removeTokenFromServer() async => journal.add('remove-fcm');

  @override
  void forgetRegisteredToken() => journal.add('forget-fcm');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
