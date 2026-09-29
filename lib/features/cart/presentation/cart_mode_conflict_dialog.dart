import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';

/// Modal affichée quand on tente d'ajouter au panier un produit dont le mode
/// (`madeToOrder` true/false) ne matche pas celui des items existants (LIL-122).
///
/// Décision 2a : une commande = un slot. On force le client à choisir entre
/// continuer sa commande actuelle, ou vider le panier pour repartir sur le
/// nouveau type de produit.
///
/// Retourne `true` si le client a choisi de vider le panier (le caller doit
/// alors clear + addItem), `false` ou `null` si annulé.
class CartModeConflictDialog extends StatelessWidget {
  /// `true` si le panier contient déjà du madeToOrder et qu'on veut ajouter
  /// un produit immédiat. `false` dans le sens inverse.
  final bool cartIsPreorder;

  /// Nom du produit qu'on essaie d'ajouter (pour personnaliser le message).
  final String incomingProductName;

  const CartModeConflictDialog({
    super.key,
    required this.cartIsPreorder,
    required this.incomingProductName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required bool cartIsPreorder,
    required String incomingProductName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CartModeConflictDialog(
        cartIsPreorder: cartIsPreorder,
        incomingProductName: incomingProductName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final existingLabel = cartIsPreorder ? 'sur commande' : 'immédiats';
    final incomingLabel = cartIsPreorder ? 'immédiat' : 'sur commande';

    return AlertDialog(
      icon: Icon(Icons.shopping_bag_outlined, color: scheme.primary, size: 32),
      title: const Text('Type de commande différent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre panier contient déjà des produits $existingLabel.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            '"$incomingProductName" est un produit $incomingLabel — vous ne pouvez pas mélanger les deux dans une même commande.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cartIsPreorder
                        ? 'Astuce : terminez votre commande sur commande, puis revenez ajouter "$incomingProductName".'
                        : 'Astuce : terminez votre commande immédiate, puis revenez ajouter "$incomingProductName".',
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Garder mon panier'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Vider et ajouter'),
          // `error`/`onError` : `Colors.red` + blanc = 3,68:1 (P3-03).
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
        ),
      ],
    );
  }
}

/// Panier d'une autre boutique (P3-13) : garder, ou vider et ajouter.
///
/// Même geste que [CartModeConflictDialog] : `true` = vider et ajouter.
class VendorConflictDialog extends StatelessWidget {
  const VendorConflictDialog({
    super.key,
    required this.currentVendorName,
    required this.incomingProductName,
  });

  /// `null` si la fiche de la boutique n'est pas en cache.
  final String? currentVendorName;
  final String incomingProductName;

  static Future<bool?> show(
    BuildContext context, {
    required String? currentVendorName,
    required String incomingProductName,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => VendorConflictDialog(
      currentVendorName: currentVendorName,
      incomingProductName: incomingProductName,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chez = currentVendorName == null
        ? 'd\'une autre boutique'
        : 'de $currentVendorName';
    return AlertDialog(
      icon: Icon(Icons.storefront_outlined, color: scheme.primary, size: 32),
      title: const Text('Changer de boutique ?'),
      content: Text(
        'Votre panier contient des articles $chez. Une commande ne peut '
        'venir que d\'une seule boutique : pour ajouter '
        '« $incomingProductName », videz d\'abord votre panier.',
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Garder mon panier'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Vider et ajouter'),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
        ),
      ],
    );
  }
}

/// Helper appelable depuis n'importe quel call-site `addToCart` (LIL-122).
///
/// Vérifie d'abord s'il y a un conflit de mode (immédiat vs sur commande).
/// Si conflit → affiche [CartModeConflictDialog]. Si le client choisit
/// "Vider et ajouter", on clear le panier puis on ajoute. Sinon on annule.
///
/// Retourne `true` si l'ajout a été **accepté localement** — c'est-à-dire
/// visible à l'écran. La synchronisation serveur se poursuit ensuite : un
/// échec la défait et part dans `cartSyncFailuresProvider`, que la coque de
/// navigation transforme en message. Retourne `false` si le client a renoncé
/// devant la modal de conflit.
///
/// Lève une [CartException] si l'ajout est refusé par une règle vérifiable
/// sans le serveur (autre vendeur, mode incompatible) — le caller l'affiche.
Future<bool> addToCartSafely({
  required BuildContext context,
  required WidgetRef ref,
  required CartItemPreview preview,
  int quantity = 1,
}) async {
  final notifier = ref.read(cartControllerProvider.notifier);
  final productMadeToOrder = preview.product.madeToOrder;

  // P3-13 — autre boutique : on propose de vider au lieu d'un message
  // d'erreur sans action (« Videz votre panier… », 4 gestes plus loin).
  final autreBoutique = notifier.conflictingVendorId(
    preview.product.restaurantId,
  );
  if (autreBoutique != null) {
    final nom = ref
        .read(restaurantControllerProvider(autreBoutique))
        .value
        ?.name;
    final shouldClear = await VendorConflictDialog.show(
      context,
      currentVendorName: nom,
      incomingProductName: preview.product.nom,
    );
    if (shouldClear != true) return false;
    await notifier.clearCart();
  } else if (notifier.wouldConflictWithCart(productMadeToOrder)) {
    // Le panier existant est dans le mode opposé à celui du nouvel item :
    // si le nouvel item est `madeToOrder=true`, alors le panier est immédiat
    // (cartIsPreorder=false), et inversement.
    final cartIsPreorder = !productMadeToOrder;
    final shouldClear = await CartModeConflictDialog.show(
      context,
      cartIsPreorder: cartIsPreorder,
      incomingProductName: preview.product.nom,
    );
    if (shouldClear != true) return false;
    await notifier.clearCart();
  }

  await notifier.addItem(
    variantId: preview.variantId,
    quantity: quantity,
    preview: preview,
  );
  return true;
}
