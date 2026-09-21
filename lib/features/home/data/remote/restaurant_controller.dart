import 'dart:async';

import 'package:lilia_app/features/home/data/remote/restaurant_repo.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/utils/provider_cache.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../models/restaurant.dart';

part 'restaurant_controller.g.dart';

/// Provider pour récupérer la liste de tous les restaurants
@riverpod
Future<List<RestaurantSummary>> restaurantsList(Ref ref) async {
  // Quitter l'accueil et y revenir ne redemande rien au serveur.
  cachePendant(ref, kCatalogCacheTtl);
  ref.watch(staleForegroundStampProvider);

  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getAllRestaurants();
}

/// Durée de vie du menu d'un vendeur en cache.
///
/// ## Pourquoi une durée, et pas `keepAlive: true`
///
/// Le provider était marqué `@Riverpod(keepAlive: true)` **sans expiration** :
/// il n'était donc jamais éliminé, et le menu restait figé pour toute la durée
/// de vie de l'application. Un client ouvrant la boutique le matin et y
/// revenant l'après-midi, l'application n'ayant pas été tuée, voyait le menu du
/// matin — anciens prix, ancien stock, ancien statut d'ouverture — sans que
/// rien à l'écran ne suggère que la donnée était vieille. Le checkout, lui,
/// lisait les vrais prix : l'écart n'apparaissait qu'au moment de payer.
///
/// L'inverse — aucun cache — serait pire : chaque reconstruction de widget
/// déclencherait un appel réseau, sur la 4G de Brazzaville.
///
/// Cinq minutes : au-delà, `availableNow` (fenêtre horaire) et `isOpen`
/// deviennent des affirmations que le serveur ne soutient plus. C'est l'ordre
/// de grandeur du `cacheLife('minutes')` posé côté web, volontairement.
const Duration kMenuCacheTtl = Duration(minutes: 5);

/// **La carte d'un vendeur**, avec un cache borné.
///
/// Trois comportements, et c'est tout ce que l'écran a besoin de savoir :
///
/// | Geste | Effet |
/// |---|---|
/// | ouverture de l'écran, cache récent | rendu immédiat, aucun appel |
/// | ouverture après `kMenuCacheTtl` | nouvel appel |
/// | retour au premier plan après `kMenuCacheTtl` | nouvel appel |
/// | tirer pour rafraîchir | nouvel appel, immédiat |
///
/// `ref.keepAlive()` + `Timer` est le motif Riverpod du cache à durée de vie :
/// le lien est maintenu, puis relâché à l'échéance, ce qui provoque une
/// reconstruction au prochain accès. `ref.onDispose` annule le minuteur — sans
/// quoi un provider détruit tôt laisserait un `Timer` en vol.
@riverpod
Future<Restaurant> restaurantController(Ref ref, String restaurantId) async {
  // Relâché à l'échéance : le prochain accès reconstruira. Entre-temps,
  // naviguer d'écran en écran et revenir ne coûte aucun appel réseau.
  final link = ref.keepAlive();
  final timer = Timer(kMenuCacheTtl, link.close);
  ref.onDispose(timer.cancel);

  // Une reprise de l'application **tardive** invalide la carte : voir
  // [StaleForegroundStamp]. Une reprise rapide ne change pas la valeur
  // observée, donc ne provoque aucun rechargement.
  ref.watch(staleForegroundStampProvider);

  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getRestaurant(restaurantId);
}

// `StaleForegroundStamp` a déménagé dans `lib/utils/provider_cache.dart`.
//
// Il y rejoint `cachePendant`, dont il est le pendant : l'un borne la durée
// de vie d'un cache, l'autre force sa relecture au retour de l'application.
// Ce sont les deux moitiés d'une même mécanique, et elle n'appartient pas au
// catalogue — le barème de `platform_settings_service` en a le même besoin,
// et l'importer d'ici aurait tiré tout le graphe restaurant dans le module
// des réglages.

/// Filtre vendor type courant pour le marketplace (LIL-117).
/// `null` = "Tous" (pas de filtre). Watched par [vendorsList].
@riverpod
class MarketplaceFilter extends _$MarketplaceFilter {
  @override
  VendorType? build() => null;

  void set(VendorType? type) => state = type;

  void reset() => state = null;
}

/// Liste paginée des vendeurs marketplace, filtrée par [marketplaceFilterProvider].
/// Hit `/vendors?vendorType=...` (Sprint B backend). Quand le filtre change,
/// Riverpod rebuilde et refetch automatiquement.
@riverpod
Future<List<RestaurantSummary>> vendorsList(Ref ref) async {
  // Idem. Le cache retient AUSSI le filtre observé juste en dessous : un
  // provider maintenu en vie garde ses dépendances, donc la puce sélectionnée
  // survit elle aussi à l'aller-retour.
  cachePendant(ref, kCatalogCacheTtl);
  ref.watch(staleForegroundStampProvider);

  final filter = ref.watch(marketplaceFilterProvider);
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getVendors(vendorType: filter);
}
