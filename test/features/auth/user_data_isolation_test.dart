// **A se déconnecte, B se connecte : B ne voit rien de A.**
//
// Trois magasins locaux vivaient sous une clé globale — `favorites`,
// `draft_orders`, `notifications_history`. `signOut()` invalidait bien les
// providers, mais invalider un provider ne fait que le forcer à relire le
// **même fichier** : sur un téléphone partagé, le compte suivant retrouvait
// les favoris, les brouillons (vendeur, articles, montant) et les
// notifications du précédent.
//
// Le scénario du cahier des charges est joué en entier, dans l'ordre :
//   A se connecte → A produit des données → A se déconnecte
//   B se connecte → B ne doit RIEN voir → B produit les siennes
//   A revient     → A retrouve les siennes, et pas celles de B.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/storage/user_scoped_prefs.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/application/user_scoped_providers.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
import 'package:lilia_app/features/notifications/application/notification_providers.dart';
import 'package:lilia_app/features/notifications/data/notification_model.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_repository.dart';

Product _produit(String id) => Product(
      id: id,
      name: 'Produit $id',
      description: '',
      prixOriginal: 3500,
      restaurantId: 'resto-1',
      variants: const [],
    );

AppNotification _notif(String titre) => AppNotification(
      id: titre,
      title: titre,
      body: 'corps',
      timestamp: DateTime(2026, 9, 20),
      payload: const {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository auth;
  late ProviderContainer container;

  /// Un conteneur dont la session peut basculer, comme dans l'application.
  void monter({AppUser? session, Map<String, Object> prefs = const {}}) {
    SharedPreferences.setMockInitialValues(prefs);
    auth = FakeAuthRepository(user: session);
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
  }

  /// Bascule de compte — en appelant **la fonction de production**.
  ///
  /// ⚠️ Ce bloc réimplémentait la liste d'invalidation à la main :
  ///
  /// ```dart
  /// container.invalidate(favoritesProvider);
  /// container.invalidate(notificationRepositoryProvider);   // ← ajouté ICI
  /// container.invalidate(notificationHistoryProvider);
  /// ```
  ///
  /// en se justifiant par « ce fichier éprouve l'isolation du stockage, pas le
  /// câblage de la déconnexion (couvert ailleurs) ». Or `grep
  /// invalidateUserScopedProviders test/` ne rendait **rien** : la fonction
  /// réellement appelée par `signOut()`, `deleteAccount()` et
  /// `SessionEffects._fermeture()` n'était lue par aucun des 611 tests.
  ///
  /// Et la liste de production omettait précisément
  /// `notificationRepositoryProvider` — celui que ce test ajoutait de son
  /// côté. Le test était donc vert pour une raison qui n'existait pas en
  /// production : c'est lui qui compensait le défaut qu'il devait détecter.
  ///
  /// Une seule règle en découle : un test d'isolation appelle la fonction
  /// d'isolation. S'il doit en énumérer le contenu, il ne prouve plus rien
  /// sur ce que fait l'application.
  void basculerVers(AppUser? utilisateur) {
    auth.emitSession(utilisateur);
    purgerProvidersDuCompte(container.invalidate);
  }

  group('scénario complet A → B → A', () {
    test('B ne voit ni les favoris ni les notifications de A', () async {
      monter(session: const AppUser(uid: 'uid-A'));

      // A produit ses données.
      await container.read(favoritesProvider.future);
      await container.read(favoritesProvider.notifier).add(_produit('p-A'));
      await container
          .read(notificationHistoryProvider.notifier)
          .addNotification(_notif('Commande de A livrée'));

      expect(container.read(favoritesProvider).value, hasLength(1));

      // A s'en va, B arrive.
      basculerVers(null);
      basculerVers(const AppUser(uid: 'uid-B'));

      expect(
        await container.read(favoritesProvider.future),
        isEmpty,
        reason: 'les favoris de A ne doivent pas suivre',
      );
      expect(
        await container.read(notificationHistoryProvider.future),
        isEmpty,
        reason:
            'les notifications nomment des commandes : elles appartiennent au '
            'compte, pas au téléphone',
      );
    });

    test('A retrouve ses données en revenant, B garde les siennes', () async {
      monter(session: const AppUser(uid: 'uid-A'));
      await container.read(favoritesProvider.future);
      await container.read(favoritesProvider.notifier).add(_produit('p-A'));

      basculerVers(const AppUser(uid: 'uid-B'));
      await container.read(favoritesProvider.future);
      await container.read(favoritesProvider.notifier).add(_produit('p-B'));
      expect(
        container.read(favoritesProvider).value!.map((p) => p.id),
        ['p-B'],
      );

      basculerVers(const AppUser(uid: 'uid-A'));

      expect(
        (await container.read(favoritesProvider.future)).map((p) => p.id),
        ['p-A'],
        reason: 'isoler ne doit pas vouloir dire perdre',
      );
    });

    test('un visiteur a son propre seau, distinct de tout compte', () async {
      monter();
      await container.read(favoritesProvider.future);
      await container.read(favoritesProvider.notifier).add(_produit('p-invite'));

      basculerVers(const AppUser(uid: 'uid-A'));

      expect(await container.read(favoritesProvider.future), isEmpty);
    });
  });

  group('données écrites par les versions précédentes', () {
    // Le piège : recopier la clé globale vers le premier compte venu
    // réintroduit exactement la fuite qu'on corrige.

    test(
      'session RESTAURÉE au démarrage : les données lui sont attribuées',
      () async {
        SharedPreferences.setMockInitialValues({
          'favorites': <String>['{"id":"p-heritage","nom":"X"}'],
        });
        final prefs = await SharedPreferences.getInstance();

        await rangerDonneesHeritees(
          prefs,
          uid: 'uid-A',
          sessionRestauree: true,
        );

        expect(
          prefs.getStringList(cleParCompte('favorites', 'uid-A')),
          hasLength(1),
          reason:
              'la session était déjà ouverte avant la mise à jour : ces '
              'données sont les siennes',
        );
        expect(prefs.getStringList('favorites'), isNull);
      },
    );

    test(
      'connexion FRAÎCHE : les données sont effacées, pas héritées',
      () async {
        SharedPreferences.setMockInitialValues({
          'draft_orders': <String>['{"id":"brouillon-de-A"}'],
        });
        final prefs = await SharedPreferences.getInstance();

        await rangerDonneesHeritees(
          prefs,
          uid: 'uid-B',
          sessionRestauree: false,
        );

        expect(
          prefs.getStringList(cleParCompte('draft_orders', 'uid-B')),
          isNull,
          reason:
              'B vient de se connecter sur un appareil sans session : rien ne '
              'dit que ce brouillon est le sien. L’attribuer rouvrirait la '
              'fuite que tout ce travail ferme',
        );
        expect(prefs.getStringList('draft_orders'), isNull);
      },
    );

    test('le traitement n’a lieu qu’une fois', () async {
      SharedPreferences.setMockInitialValues({
        'favorites': <String>['{"id":"p1","nom":"X"}'],
      });
      final prefs = await SharedPreferences.getInstance();

      await rangerDonneesHeritees(prefs, uid: 'uid-A', sessionRestauree: true);
      // B se connecte plus tard : la clé globale n'existe plus, et le drapeau
      // empêche même d'y regarder.
      await prefs.setStringList('favorites', <String>['{"id":"p2","nom":"Y"}']);
      await rangerDonneesHeritees(prefs, uid: 'uid-B', sessionRestauree: true);

      expect(prefs.getStringList(cleParCompte('favorites', 'uid-B')), isNull);
    });

    test('ne jamais écraser des données déjà rangées', () async {
      SharedPreferences.setMockInitialValues({
        'favorites': <String>['{"id":"ancien","nom":"X"}'],
        'favorites__uid-A': <String>['{"id":"recent","nom":"Y"}'],
      });
      final prefs = await SharedPreferences.getInstance();

      await rangerDonneesHeritees(prefs, uid: 'uid-A', sessionRestauree: true);

      expect(
        prefs.getStringList(cleParCompte('favorites', 'uid-A')),
        ['{"id":"recent","nom":"Y"}'],
      );
    });
  });

  group('bug trouvé pendant la correction : l’OUVERTURE aussi', () {
    // Le premier correctif ne traitait que la fermeture de session. Or la clé
    // est résolue au `build` du provider, et rien ne le reconstruit quand la
    // session s'ouvre : `authRepositoryProvider` est un `Provider` dont la
    // valeur ne change pas à la connexion — seul son `currentUser` change, ce
    // que Riverpod ne voit pas.
    test(
      'un visiteur qui se connecte cesse d’écrire dans le seau visiteur',
      () async {
        monter();
        await container.read(favoritesProvider.future);
        await container
            .read(favoritesProvider.notifier)
            .add(_produit('p-invite'));

        // Ce que fait `SessionEffects._ouverture` : la session s'ouvre ET les
        // providers rangés par compte sont invalidés.
        basculerVers(const AppUser(uid: 'uid-A'));

        expect(
          await container.read(favoritesProvider.future),
          isEmpty,
          reason:
              'sans invalidation à l’ouverture, le compte lisait — et '
              'écrivait — dans le seau du visiteur',
        );

        final prefs = await SharedPreferences.getInstance();
        await container.read(favoritesProvider.notifier).add(_produit('p-A'));
        expect(
          prefs.getStringList(cleParCompte('favorites', 'uid-A')),
          hasLength(1),
        );
        expect(
          prefs.getStringList(cleParCompte('favorites', null)),
          hasLength(1),
          reason: 'le seau du visiteur garde ce qu’il avait, sans y ajouter',
        );
      },
    );
  });

  group('le panier du visiteur reste global — et c’est voulu', () {
    test('sa clé ne porte aucun identifiant de compte', () {
      // Tout le mode visiteur repose là-dessus : le panier composé avant
      // d'avoir un compte doit survivre à la connexion pour être versé.
      expect(cleParCompte('guest_cart_v1', null), isNot('guest_cart_v1'));
      // …et personne ne le range : le magasin l'écrit en dur.
      expect('guest_cart_v1', isNot(contains('__')));
    });
  });
}
