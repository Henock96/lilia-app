import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/features/cart/presentation/cart_mode_conflict_dialog.dart';
import 'package:lilia_app/features/cart/presentation/product_options_gate.dart';
import 'package:lilia_app/features/home/presentation/widgets/product_stock_widgets.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/snackbar.dart';

/// Ce que fera le bouton d'ajout rapide d'une carte produit.
///
/// Sert à la fois au geste ([quickAddProduct]) et à son libellé accessible :
/// un « + » qui ouvre un choix de format ne s'annonce pas « Ajouter ».
enum QuickAddAction {
  /// Un seul format, vendable : ajout direct.
  addDirectly,

  /// Plusieurs formats : le client choisit avant tout ajout.
  chooseVariant,

  /// Options (F3-09) : le choix se fait sur la fiche.
  openProduct,

  /// Aucun format vendable d'après le verdict serveur.
  unavailable,
}

QuickAddAction quickAddActionFor(Product product) {
  // Verdict produit d'abord (boutique fermée, retiré, hors créneau…) : un
  // « + » actif sur un produit non commandable promet un ajout que le serveur
  // refusera.
  if (!product.isOrderable) return QuickAddAction.unavailable;
  if (product.hasModifiers) return QuickAddAction.openProduct;
  final variants = product.variants;
  if (variants.isEmpty) return QuickAddAction.unavailable;
  if (variants.length > 1) {
    return variants.any((v) => v.isInStock)
        ? QuickAddAction.chooseVariant
        : QuickAddAction.unavailable;
  }
  return variants.single.isInStock
      ? QuickAddAction.addDirectly
      : QuickAddAction.unavailable;
}

String quickAddSemanticLabel(Product product) =>
    switch (quickAddActionFor(product)) {
      QuickAddAction.addDirectly => 'Ajouter ${product.name} au panier',
      QuickAddAction.chooseVariant => 'Choisir un format pour ${product.name}',
      QuickAddAction.openProduct => 'Personnaliser ${product.name}',
      QuickAddAction.unavailable => '${product.name} indisponible',
    };

/// Pourquoi l'ajout rapide est refusé, dit au client dans ses mots.
String quickAddUnavailableMessage(Product product) =>
    switch (product.unavailability) {
      ProductUnavailability.boutiqueFermee =>
        '${product.restaurantName ?? 'La boutique'} est fermée pour le moment.',
      ProductUnavailability.retire =>
        '${product.name} n\'est plus proposé pour le moment.',
      ProductUnavailability.horsCreneau =>
        '${product.name} n\'est pas disponible à cette heure-ci.',
      ProductUnavailability.optionsIndisponibles =>
        '${product.name} est indisponible pour le moment.',
      ProductUnavailability.epuise =>
        '${product.name} est épuisé pour le moment.',
      null =>
        product.variants.isEmpty
            ? '${product.name} n\'a pas de format disponible.'
            : '${product.name} est épuisé pour le moment.',
    };

/// **Le seul chemin d'ajout rapide** depuis une carte produit (accueil,
/// recherche, recommandations, suggestions du panier, carte vendeur).
///
/// Chacun de ces écrans portait sa propre copie du geste, et elles avaient
/// divergé : feuille de formats qui laissait choisir un format épuisé, ajout
/// direct d'un format unique épuisé (succès affiché, puis annulé par le
/// serveur), conflit « sur commande / immédiat » montré comme une erreur au
/// lieu de la modale qui propose de vider le panier, et trois écrans sur cinq
/// qui refusaient le visiteur alors que le panier invité existe.
///
/// Règle : **aucun format n'est choisi à la place du client**. Un format
/// unique s'ajoute directement ; au-delà, on demande. Le stock affiché est le
/// verdict du serveur (`stockStatus`), jamais recalculé ici.
///
/// [multipleVariantsOpenProduct] : la carte vendeur ouvre la fiche plutôt
/// que la feuille (parité avec le site, où le bouton reste inactif tant
/// qu'aucun format n'est choisi).
Future<void> quickAddProduct(
  BuildContext context,
  WidgetRef ref,
  Product product, {
  bool multipleVariantsOpenProduct = false,
}) async {
  // F3-09 — un produit à options s'ajoute depuis sa fiche.
  if (openProductForOptions(context, product)) return;

  final ProductVariant variant;
  switch (quickAddActionFor(product)) {
    case QuickAddAction.openProduct:
      return; // traité par openProductForOptions
    case QuickAddAction.unavailable:
      context.showSnack(quickAddUnavailableMessage(product));
      return;
    case QuickAddAction.addDirectly:
      variant = product.variants.single;
    case QuickAddAction.chooseVariant:
      if (multipleVariantsOpenProduct) {
        context.pushNamed(
          AppRoutes.productDetail.routeName,
          pathParameters: {'productId': product.id},
          extra: product,
        );
        return;
      }
      final choisi = await showVariantSelectionSheet(context, product);
      if (choisi == null || !context.mounted) return;
      variant = choisi;
  }

  try {
    // `addToCartSafely` et non `addItem` : il pose la question du conflit de
    // mode (immédiat / sur commande) au lieu de le lever comme une erreur.
    final added = await addToCartSafely(
      context: context,
      ref: ref,
      preview: CartItemPreview.fromProduct(product, variant),
    );
    // L'ajout est optimiste : le message part dans la foulée du tap. Un refus
    // serveur défait la ligne et s'affiche depuis la coque de navigation
    // (`cartSyncFailuresProvider`) ; `add_to_cart` n'est compté qu'à
    // l'acceptation, par le contrôleur.
    if (added && context.mounted) {
      final format = product.variants.length > 1
          ? ' (${variant.displayLabel})'
          : '';
      context.showSuccessSnack('${product.name}$format ajouté au panier');
    }
  } on CartException catch (e) {
    if (context.mounted) context.showErrorSnack(e.message);
  }
}

/// Le « + » des cartes produit. Remplace quatre copies (28, 32 et 36 px de
/// `GestureDetector` nu) qui avaient trois défauts communs :
///
/// - zone de tap sous 48 px (règle Android, `androidTapTargetGuideline`) ;
/// - aucune sémantique : TalkBack lisait « bouton » sans dire lequel, et un
///   « + » qui ouvre un choix de format s'annonçait comme un ajout ;
/// - `Colors.white` sur `primary` — illisible en sombre, où l'action est un
///   orange clair (voir `LiliaThemeTokens.textOnAction`).
///
/// [visualSize] garde le dessin d'origine de chaque carte ; la zone de tap
/// l'entoure jusqu'à 48 px.
class QuickAddButton extends ConsumerWidget {
  const QuickAddButton({
    super.key,
    required this.product,
    this.visualSize = 32,
    this.multipleVariantsOpenProduct = false,
  });

  final Product product;
  final double visualSize;
  final bool multipleVariantsOpenProduct;

  static const double _minTapTarget = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final action = quickAddActionFor(product);
    final hit = visualSize < _minTapTarget ? _minTapTarget : visualSize;
    return Semantics(
      // Nœud propre : sinon, posé dans une carte elle-même tappable, son
      // libellé fusionnait avec celui de la carte et le bouton disparaissait
      // pour TalkBack / VoiceOver.
      container: true,
      button: true,
      label: quickAddSemanticLabel(product),
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => quickAddProduct(
          context,
          ref,
          product,
          multipleVariantsOpenProduct: multipleVariantsOpenProduct,
        ),
        radius: hit / 2,
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: LiliaRadius.smAll,
              ),
              child: SizedBox.square(
                dimension: visualSize,
                child: Icon(
                  // Un format à choisir ne s'ajoute pas en un tap : l'icône
                  // le dit avant le geste.
                  action == QuickAddAction.addDirectly
                      ? Icons.add
                      : Icons.tune_rounded,
                  color: cs.onPrimary,
                  size: visualSize * 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
