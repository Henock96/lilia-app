import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../cart/application/cart_controller.dart';
import '../../cart/application/draft_orders_provider.dart';
import '../../commandes/data/order_controller.dart';
import '../../commandes/data/order_repository.dart';
import '../../favoris/application/favorites_provider.dart';
import '../../favoris/application/restaurant_favorites_provider.dart';
import '../../notifications/application/notification_providers.dart';
import '../../user/application/adresse_controller.dart';
import '../../user/application/profile_controller.dart';
import '../../user/data/adresse_repository.dart';

/// Tout ce qui appartient au compte qui s'en va.
///
/// ## Pourquoi cette liste vit seule, dans son propre fichier
///
/// Elle avait **deux** appelants — la déconnexion et la suppression de compte —
/// qui en portaient chacun une copie de douze lignes. Elle en a désormais
/// trois : [SessionEffects] l'appelle aussi à la fermeture de session, pour
/// couvrir les sorties qui ne passent pas par `AuthController.signOut()` (jeton
/// révoqué côté serveur, compte supprimé depuis la console Firebase).
///
/// Trois copies d'une liste qu'on complète à chaque nouveau provider, c'est la
/// garantie qu'un jour l'une d'elles sera oubliée — et une fuite entre comptes
/// ne se voit pas à la relecture. Une seule définition, trois appels.
///
/// ⚠️ `restaurantFavoritesProvider` est `keepAlive` : sans invalidation, les
/// favoris du compte précédent restaient visibles après reconnexion (C10).
///
/// ⚠️ Cette fonction ne vide **pas** les magasins locaux (favoris produits,
/// brouillons, historique de notifications). Ils sont désormais rangés par
/// identifiant de compte (`*_<uid>`) : invalider le provider suffit à le faire
/// relire la bonne clé. Voir `user_scoped_prefs.dart`.
/// [inclureLePanier] — à mettre à `false` juste avant `adoptGuestCart`.
///
/// Invalider le panier provoque un `build()` qui relit `GET /cart`, pendant
/// que `adoptGuestCart` verse les lignes et pose l'état final. Les deux
/// écritures se courent après, et la relecture — partie avant le versement —
/// peut arriver après lui : l'écran afficherait alors le panier d'AVANT
/// l'adoption, jusqu'à la lecture suivante. Le contenu serveur est juste dans
/// les deux cas ; c'est l'affichage qui reculerait.

// ─────────────────────────────────────────────────────────────────────────────

/// **La table** — tout ce qui appartient au compte, en un seul endroit.
///
/// ⚠️ `notificationRepositoryProvider` y manquait, et son absence ne se voyait
/// pas. C'est le **magasin** : il résout `notifications_history__<uid>` à son
/// `build` depuis `authRepositoryProvider.currentUser?.uid`. Son `ref.watch`
/// ne le reconstruit jamais — `authRepositoryProvider` est un `Provider` dont
/// la *valeur* ne change pas à la connexion, seul son `currentUser` change, ce
/// que Riverpod ne voit pas (même piège que `SessionEffects._ouverture`
/// documente). Seul `notificationHistoryProvider`, l'**état**, était invalidé :
/// reconstruit, il re-lisait un magasin resté sur l'uid du compte parti.
///
/// La table est exposée parce que la liste est la chose qu'on oublie de
/// compléter, et qu'une liste sans test est une liste qui dérive. Même
/// raisonnement que `protectedLocationPrefixes` dans
/// `protected_locations.dart`.
final List<ProviderOrFamily> kProvidersDuCompte = List<ProviderOrFamily>.unmodifiable(<ProviderOrFamily>[
  notificationHistoryProvider,
  notificationRepositoryProvider,
  orderRepositoryProvider,
  userOrdersProvider,
  favoritesProvider,
  restaurantFavoritesProvider,
  userProfileProvider,
  referralStatsProvider,
  loyaltyTransactionsProvider,
  adresseControllerProvider,
  adresseRepositoryProvider,
  draftOrdersProvider,
]);

void invalidateUserScopedProviders(Ref ref, {bool inclureLePanier = true}) =>
    purgerProvidersDuCompte(ref.invalidate, inclureLePanier: inclureLePanier);

/// La purge elle-même, séparée de la source d'invalidation.
///
/// ## Pourquoi ce paramètre plutôt qu'un `Ref`
///
/// `invalidateUserScopedProviders(Ref)` n'était **appelable par aucun test** :
/// un test dispose d'un `ProviderContainer`, pas d'un `Ref`, et les deux ne
/// partagent aucune interface publique (`BaseRef` est `@internal`).
///
/// Ce n'était pas un détail de typage. C'est ce qui a permis à
/// `user_data_isolation_test` de réimplémenter la liste à la main — en y
/// ajoutant justement le provider que la production oubliait. Le test était
/// vert, la production fuyait, et `grep invalidateUserScopedProviders test/`
/// ne rendait rien.
///
/// Les deux `invalidate` — celui de `Ref` et celui de `ProviderContainer` —
/// ont la même forme. En prendre la référence rend la fonction appelable des
/// deux côtés, et le test exerce désormais le vrai code.
@visibleForTesting
void purgerProvidersDuCompte(
  void Function(ProviderOrFamily provider) invalider, {
  bool inclureLePanier = true,
}) {
  if (inclureLePanier) invalider(cartControllerProvider);
  for (final provider in kProvidersDuCompte) {
    invalider(provider);
  }
}
