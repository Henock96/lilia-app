// Quitter l'accueil et y revenir ne doit coûter aucun appel réseau.
//
// C'est la garantie déjà écrite pour la carte d'un vendeur
// (`restaurant_controller.dart`, `kMenuCacheTtl`) : « naviguer d'écran en écran
// et revenir ne coûte aucun appel ». Les quatre listes de l'accueil ne
// l'avaient pas.
//
// Ce que ce test reproduit : l'écran de connexion **remplace** la coque
// (`redirect` → `go`), donc `HomeScreen` est détruit, donc les providers
// `autoDispose` qu'il observe perdent leur dernier auditeur. Au retour, tout
// était rechargé — quatre appels, sur la 4G de Brazzaville.
//
// Le harnais ne monte aucun widget : abonner puis désabonner un provider EST
// exactement ce que fait un écran qui part et revient, et c'est mesurable sans
// arbre de widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/home/data/remote/banner_controller.dart';
import 'package:lilia_app/features/home/data/remote/banner_repo.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/data/remote/home_repo.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_repo.dart';
import 'package:lilia_app/models/banner.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

class _RestaurantRepoCompteur implements RestaurantRepository {
  int appelsVendors = 0;
  int appelsRestaurants = 0;

  @override
  Future<List<RestaurantSummary>> getVendors({VendorType? vendorType}) async {
    appelsVendors++;
    return const <RestaurantSummary>[];
  }

  @override
  noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getRestaurants) {
      appelsRestaurants++;
      return Future<List<RestaurantSummary>>.value(const <RestaurantSummary>[]);
    }
    return super.noSuchMethod(invocation);
  }
}

class _BannerRepoCompteur implements BannerRepository {
  int appels = 0;

  @override
  noSuchMethod(Invocation invocation) {
    appels++;
    return Future<List<AppBanner>>.value(const <AppBanner>[]);
  }
}

class _HomeRepoCompteur implements HomeRepository {
  int appels = 0;

  @override
  noSuchMethod(Invocation invocation) {
    appels++;
    return Future<List<Product>>.value(const <Product>[]);
  }
}

void main() {
  // `StaleForegroundStamp` s'abonne au cycle de vie de l'application : sans
  // liaison initialisée, les providers qui l'observent partent en erreur.
  // `runApp` s'en charge en production.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RestaurantRepoCompteur restaurants;
  late _BannerRepoCompteur bannieres;
  late _HomeRepoCompteur accueil;
  late ProviderContainer container;

  setUp(() {
    restaurants = _RestaurantRepoCompteur();
    bannieres = _BannerRepoCompteur();
    accueil = _HomeRepoCompteur();
    container = ProviderContainer(
      overrides: [
        restaurantRepositoryProvider.overrideWithValue(restaurants),
        bannerRepositoryProvider.overrideWithValue(bannieres),
        homeRepositoryProvider.overrideWithValue(accueil),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Abonner puis désabonner EST ce que fait un écran qui part et revient —
  /// inutile de monter un arbre de widgets pour l'observer.

  test('la liste des vendeurs survit à un aller-retour', () async {
    for (var i = 0; i < 2; i++) {
      final abonnement = container.listen(vendorsListProvider, (_, _) {});
      await container.read(vendorsListProvider.future);
      abonnement.close();
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      restaurants.appelsVendors,
      1,
      reason: 'le retour ne doit déclencher aucun second appel',
    );
  });

  test('les bannières survivent à un aller-retour', () async {
    for (var i = 0; i < 2; i++) {
      final abonnement = container.listen(bannersListProvider, (_, _) {});
      await container.read(bannersListProvider.future);
      abonnement.close();
      await Future<void>.delayed(Duration.zero);
    }
    expect(bannieres.appels, 1);
  });

  test('les produits populaires survivent à un aller-retour', () async {
    for (var i = 0; i < 2; i++) {
      final abonnement = container.listen(popularProductsProvider, (_, _) {});
      await container.read(popularProductsProvider.future);
      abonnement.close();
      await Future<void>.delayed(Duration.zero);
    }
    expect(accueil.appels, 1);
  });

  test('le filtre marketplace survit lui aussi à un aller-retour', () async {
    // Le cache retient la liste ; la liste observe le filtre ; un provider
    // maintenu en vie garde ses dépendances. La puce sélectionnée devrait donc
    // être encore là au retour — sinon le client retrouve « Tous » après être
    // passé par la connexion.
    container.read(marketplaceFilterProvider.notifier).set(VendorType.BAKERY);

    final abonnement = container.listen(vendorsListProvider, (_, _) {});
    await container.read(vendorsListProvider.future);
    abonnement.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(marketplaceFilterProvider), VendorType.BAKERY);
    expect(restaurants.appelsVendors, 1);
  });
}
