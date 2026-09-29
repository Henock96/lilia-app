import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/utils/snackbar.dart';

/// Raisons des lignes non rachetées (au plus trois), telles que le serveur
/// les formule.
List<String> reorderReasons(Map<String, dynamic> result) {
  final details = result['details'];
  final unavailable = details is Map<String, dynamic>
      ? details['unavailable']
      : null;
  if (unavailable is! List) return const [];
  return unavailable
      .whereType<Map<String, dynamic>>()
      .map((u) => u['reason'])
      .whereType<String>()
      .take(3)
      .map((r) => '• $r')
      .toList();
}

/// Recopie une commande passée dans le panier — `POST /orders/:id/reorder`.
///
/// Le **serveur** décide de ce qui est rachetable (produit, format, options,
/// stock — `order-reorder.service.ts`) et renvoie les lignes écartées avec
/// leur raison : rien n'est ajouté à l'aveugle, et les prix sont ceux
/// d'aujourd'hui. L'ouverture de la boutique n'est pas vérifiée à ce stade :
/// elle l'est au checkout, qui suit le parcours normal (devis, frais, promos).
///
/// Partagé par le détail et la **liste** des commandes (P3-22) : il n'était
/// accessible que depuis le détail.
Future<void> reorderIntoCart(
  BuildContext context,
  WidgetRef ref,
  String orderId,
) async {
  // Show loading dialog
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final result = await ref
        .read(cartControllerProvider.notifier)
        .reorder(orderId: orderId);

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

    final summary = result['summary'] as Map<String, dynamic>? ?? {};
    // Typés explicitement : ces valeurs viennent d'un Map<String, dynamic>
    // et servaient directement de condition (`totalAdded > 0`).
    final int totalAdded =
        (summary['totalAdded'] as int?) ?? (result['totalAdded'] as int?) ?? 0;
    final int totalUnavailable =
        (summary['totalUnavailable'] as int?) ??
        (result['totalUnavailable'] as int?) ??
        0;

    if (totalAdded > 0) {
      String message =
          '$totalAdded article${totalAdded > 1 ? 's' : ''} ajouté${totalAdded > 1 ? 's' : ''} au panier';
      if (totalUnavailable > 0) {
        message +=
            '\n$totalUnavailable article${totalUnavailable > 1 ? 's' : ''} indisponible${totalUnavailable > 1 ? 's' : ''}';
        // F3-10 — dire pourquoi (format retiré, stock insuffisant…) : le
        // serveur n'ajoute plus jamais un autre format à la place.
        final reasons = reorderReasons(result);
        if (reasons.isNotEmpty) message += ' :\n${reasons.join('\n')}';
      }

      context.showSnack(
        message,
        type: SnackType.success,
        action: SnackBarAction(
          label: 'Voir le panier',
          textColor: Colors.white,
          onPressed: () => context.go('/cart'),
        ),
      );
    } else {
      context.showErrorSnack('Aucun article disponible pour cette commande');
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

    // Le serveur nomme lui-même le conflit (« …d'un autre restaurant.
    // Veuillez le vider… ») : on affiche son message, traduit s'il s'agit
    // d'une panne, au lieu de chercher un mot dans `e.toString()`.
    context.showErrorSnack(
      userFacingErrorMessage(e),
      duration: const Duration(seconds: 5),
    );
  }
}
