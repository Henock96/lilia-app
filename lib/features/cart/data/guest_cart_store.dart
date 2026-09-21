import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/core/log.dart';

part 'guest_cart_store.g.dart';

/// Le panier d'un visiteur qui n'a pas encore de compte.
///
/// ## Pourquoi il existe
///
/// Le panier de Lilia Food vit sur le serveur : les six routes `/cart/*`
/// exigent un jeton Firebase, et `getCart()` rend `null` sur 401. Tant que
/// l'accueil était fermé aux visiteurs, cela suffisait. Ouvrir la découverte
/// sans ouvrir le panier aurait produit le pire des deux : un catalogue
/// consultable dont le bouton « Ajouter » ne fait rien.
///
/// ## Ce qu'il n'est pas
///
/// Ce n'est pas un second modèle de panier. Il stocke exactement le même
/// `Cart`, muté par exactement les mêmes fonctions pures
/// (`cart_mutations.dart`) que celles qui produisent l'affichage optimiste du
/// panier serveur. Un visiteur et un client connecté voient donc le même écran,
/// construit par le même code — il n'y a qu'une seule notion de panier dans
/// l'application.
///
/// ## Ce qu'il ne stocke pas
///
/// Les **menus**. Leur composition n'est connue que du serveur (`CartMenus
/// Service` dépile le menu en lignes) ; la fabriquer localement inventerait un
/// contenu. Un visiteur qui ajoute un menu est donc invité à se connecter à ce
/// moment-là — c'est le seul geste du catalogue qui le demande, et il est rare.
///
/// ## Durée de vie
///
/// `SharedPreferences`, comme les brouillons de commande. Il survit donc à la
/// fermeture de l'application : quelqu'un qui compose un panier le soir et
/// revient le lendemain le retrouve. Il est **effacé** dès qu'il a été versé
/// dans un panier serveur — jamais avant, et jamais sans l'avoir été.
class GuestCartStore {
  GuestCartStore(this._prefs);

  final SharedPreferences _prefs;

  /// Clé versionnée : un changement de forme du panier stocké se traduira par
  /// une nouvelle clé, pas par une lecture qui échoue silencieusement.
  static const String storageKey = 'guest_cart_v1';

  /// Identifiant du panier local. Reconnaissable, et il ne part jamais au
  /// serveur : la réponse de `POST /cart/add` remplace le panier entier.
  static const String localCartId = 'guest-cart';

  /// Le panier du visiteur, ou `null` s'il n'y en a pas.
  ///
  /// Toute donnée illisible (format changé, écriture interrompue) vaut « pas de
  /// panier » : un visiteur avec un panier vide est un état normal, un écran
  /// qui refuse de s'ouvrir n'en est pas un.
  Cart? read() {
    final brut = _prefs.getString(storageKey);
    if (brut == null || brut.isEmpty) return null;
    try {
      final decode = jsonDecode(brut);
      if (decode is! Map<String, dynamic>) return null;
      final items = decode['items'];
      if (items is! List) return null;
      return Cart(
        id: localCartId,
        userId: '',
        items: items
            .whereType<Map<String, dynamic>>()
            .map(CartItem.fromMap)
            .toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      logDebug('Panier invité illisible, ignoré : $e');
      return null;
    }
  }

  /// Écrit le panier du visiteur. Un panier vide est **effacé** plutôt que
  /// stocké vide : les deux disent la même chose, et l'absence de clé est plus
  /// facile à raisonner.
  Future<void> write(Cart? cart) async {
    if (cart == null || cart.items.isEmpty) return clear();
    await _prefs.setString(
      storageKey,
      jsonEncode({'items': cart.items.map((i) => i.toMap()).toList()}),
    );
  }

  Future<void> clear() => _prefs.remove(storageKey).then((_) {});
}

/// `SharedPreferences` derrière un provider : c'est le seul point d'injection
/// des tests, qui posent `SharedPreferences.setMockInitialValues({})`.
@Riverpod(keepAlive: true)
Future<GuestCartStore> guestCartStore(Ref ref) async =>
    GuestCartStore(await SharedPreferences.getInstance());
