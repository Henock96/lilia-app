import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lilia_app/core/log.dart';

/// **Le stockage local, rangé par compte.**
///
/// ## Ce qui fuyait
///
/// Trois magasins vivaient sous une clé globale :
///
/// | Magasin | Ancienne clé | Contenu |
/// |---|---|---|
/// | Favoris produits | `favorites` | ce que le client aime |
/// | Brouillons de commande | `draft_orders` | vendeur, articles, **montant** |
/// | Historique de notifications | `notifications_history` | titres et corps |
///
/// `AuthController.signOut()` invalidait bien les trois providers — mais
/// invalider un provider ne fait que le forcer à **relire le même fichier**.
/// Sur un téléphone partagé, cas courant à Brazzaville, le compte suivant
/// retrouvait donc les favoris, les brouillons et les notifications du
/// précédent. Les brouillons sont les plus parlants : ils nomment un vendeur,
/// listent des articles et affichent un total.
///
/// ## La règle
///
/// Une clé par compte : `favorites__<uid>`. Sans session, un seau `__invite`
/// séparé — un visiteur peut mettre un produit en favori depuis la fiche
/// produit, qui est publique.
///
/// ⚠️ **Le panier du visiteur n'est pas concerné.** `guest_cart_v1` reste
/// délibérément global : c'est un panier composé *avant* d'avoir un compte, et
/// tout le mode visiteur repose sur le fait qu'il survive à la connexion pour
/// être versé (`CartController.adoptGuestCart`). Le ranger par compte le
/// rendrait introuvable au moment précis où il sert.
String cleParCompte(String base, String? uid) =>
    '${base}__${uid ?? 'invite'}';

/// Les anciennes clés globales, et le drapeau qui dit qu'on les a traitées.
const _clesHeritees = <String>[
  'favorites',
  'draft_orders',
  'notifications_history',
];
const _drapeauTraitement = 'local_data_scoped_v1';

/// Que faire des données écrites par les versions précédentes.
///
/// ## Pourquoi ce n'est pas une simple migration
///
/// Recopier `favorites` vers `favorites__<uid>` au premier compte venu
/// **réintroduirait exactement la fuite qu'on corrige** : si A s'est
/// déconnecté avant la mise à jour et que B se connecte après, B hériterait
/// des favoris et des brouillons de A. Une migration naïve est ici pire que
/// pas de migration.
///
/// La distinction qui tranche est [sessionRestauree] :
///
/// * **session restaurée au démarrage** — l'application s'ouvre sur une
///   session déjà ouverte, celle qui était en cours *avant* la mise à jour.
///   Ces données lui appartiennent : on les lui attribue.
/// * **connexion faite dans la session courante** — quelqu'un vient de se
///   connecter sur un appareil qui n'avait personne. Rien ne dit que ces
///   données sont les siennes : on les efface.
///
/// Dans les deux cas les anciennes clés disparaissent, donc l'opération n'a
/// lieu qu'une fois — [_drapeauTraitement] évite même de la retenter.
Future<void> rangerDonneesHeritees(
  SharedPreferences prefs, {
  required String uid,
  required bool sessionRestauree,
}) async {
  if (prefs.getBool(_drapeauTraitement) ?? false) return;

  for (final base in _clesHeritees) {
    final heritee = prefs.getStringList(base);
    if (heritee == null) continue;

    if (sessionRestauree) {
      final destination = cleParCompte(base, uid);
      // Ne jamais écraser des données déjà rangées : si le compte a commencé
      // à en produire, ce sont elles qui font foi.
      if (prefs.getStringList(destination) == null) {
        await prefs.setStringList(destination, heritee);
      }
    }
    await prefs.remove(base);
  }

  await prefs.setBool(_drapeauTraitement, true);
  if (kDebugMode) {
    logDebug(
      sessionRestauree
          ? 'Données locales héritées attribuées à la session restaurée.'
          : 'Données locales héritées effacées : leur propriétaire est inconnu.',
    );
  }
}
