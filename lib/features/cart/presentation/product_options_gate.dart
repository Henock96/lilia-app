import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

/// F3-09 — un produit à options ne s'ajoute pas « en un tap ».
///
/// Les ajouts rapides (accueil, recherche, recommandations, carte vendeur,
/// panier, favoris) posaient la variante seule. Sur un produit dont un groupe
/// est obligatoire, le serveur refuserait (`MODIFIER_REQUIRED`) ; sur un
/// produit à suppléments facultatifs, on priverait le client d'un choix qu'il
/// n'a pas vu. Ces gestes ouvrent donc la fiche, où le choix est explicite —
/// le parti déjà pris pour les produits à plusieurs formats.
///
/// Rend `true` si la fiche a été ouverte : l'appelant s'arrête là.
bool openProductForOptions(BuildContext context, Product product) {
  if (!product.hasModifiers) return false;
  context.pushNamed(
    AppRoutes.productDetail.routeName,
    pathParameters: {'productId': product.id},
    extra: product,
  );
  return true;
}
