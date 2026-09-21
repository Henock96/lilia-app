/// **La référence lisible d'une commande — une seule, partout.**
///
/// ## Deux défauts, une cause
///
/// Cinq écrans écrivaient `order.id.substring(0, 8).toUpperCase()`, et un
/// sixième `checkout.id.substring(checkout.id.length - 6).toUpperCase()`.
///
/// **1. Une même commande portait deux références.** La liste affichait
/// `#CMHZ4K2P`, la modale de reprise de paiement `n°9TXQ4A`. Un client qui
/// cite la seconde au support, qui cherche la première, n'est pas retrouvé.
/// C'est le genre d'écart qui ne se voit jamais en relecture — les deux lignes
/// sont dans des fichiers différents — et toujours au téléphone.
///
/// **2. `substring(0, 8)` lève un `RangeError` sur un identifiant court.**
/// Les identifiants sont des cuid, donc le cas ne se produit pas… sauf à
/// `commande_page.dart:47`, où la valeur vient d'une **charge utile FCM**,
/// c'est-à-dire de l'extérieur. Un `orderId` court dans un push mal formé
/// plantait l'écran des commandes.
///
/// ## La règle
///
/// Huit caractères, en majuscules, préfixés `#`. Huit et non six : sur un cuid
/// les premiers caractères portent l'horodatage, donc deux commandes du même
/// jour partagent un préfixe — six ne suffit pas à les distinguer de façon
/// fiable dans une conversation de support.
///
/// Un identifiant plus court est rendu **en entier** plutôt que tronqué : il
/// vaut mieux une référence inhabituelle qu'un écran qui plante.
library;

/// `#CMHZ4K2P` — la référence à montrer au client, et à lui faire citer.
String refCommande(String? orderId) {
  final id = orderId?.trim() ?? '';
  if (id.isEmpty) return '#—';
  final court = id.length <= 8 ? id : id.substring(0, 8);
  return '#${court.toUpperCase()}';
}
