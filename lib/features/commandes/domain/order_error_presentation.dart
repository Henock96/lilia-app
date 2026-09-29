import 'package:flutter/material.dart';

import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/core/network/api_exception.dart';

/// Catégorie d'un échec de création de commande, telle que le client doit la
/// comprendre.
enum OrderErrorKind {
  /// La requête est peut-être arrivée : **issue inconnue**. On ne dit ni
  /// « échec » ni « succès ».
  outcomeUnknown,

  /// Rien n'est parti : pas de réseau.
  offline,
  sessionExpired,
  vendorClosed,
  outOfStock,
  belowMinimum,
  emptyCart,
  address,
  promo,
  generic,
}

/// Titre, message et icône du dialogue d'échec du checkout.
///
/// Remplace un `error.toString()` suivi de `contains` sur le texte brut : un
/// délai dépassé s'affichait « Erreur de commande — Le serveur met trop de
/// temps à répondre », ce qui laissait croire à un échec alors que la commande
/// avait pu être créée. Le checkout garde sa clé d'idempotence tant que la
/// commande n'est pas confirmée : réessayer ne crée pas de doublon.
class OrderErrorPresentation {
  const OrderErrorPresentation({
    required this.kind,
    required this.title,
    required this.message,
    required this.icon,
  });

  final OrderErrorKind kind;
  final String title;
  final String message;
  final IconData icon;

  factory OrderErrorPresentation.from(Object error) {
    if (error is ApiException) {
      if (error.kind == ApiErrorKind.timeout) {
        return const OrderErrorPresentation(
          kind: OrderErrorKind.outcomeUnknown,
          title: 'Commande non confirmée',
          message:
              'La réponse du serveur n\'est pas arrivée à temps. Votre commande '
              'a peut-être été enregistrée : vérifiez « Mes commandes » avant '
              'de réessayer. Réessayer depuis cet écran ne la créera pas deux '
              'fois.',
          icon: Icons.hourglass_bottom_rounded,
        );
      }
      if (error.kind == ApiErrorKind.network) {
        return const OrderErrorPresentation(
          kind: OrderErrorKind.offline,
          title: 'Pas de connexion',
          message:
              'Votre commande n\'a pas pu être envoyée. Vérifiez votre accès '
              'à internet puis réessayez.',
          icon: Icons.wifi_off_rounded,
        );
      }
      if (error.kind == ApiErrorKind.unauthorized) {
        return const OrderErrorPresentation(
          kind: OrderErrorKind.sessionExpired,
          title: 'Session expirée',
          message:
              'Reconnectez-vous pour finaliser votre commande. Votre '
              'panier est conservé.',
          icon: Icons.lock_outline_rounded,
        );
      }
    }

    final message = userFacingErrorMessage(error);
    final m = message.toLowerCase();
    (OrderErrorKind, String, IconData) c;
    if (m.contains('fermé')) {
      c = (OrderErrorKind.vendorClosed, 'Boutique fermée', Icons.store_rounded);
    } else if (m.contains('rupture') ||
        m.contains('stock') ||
        m.contains('épuisé')) {
      c = (
        OrderErrorKind.outOfStock,
        'Produit indisponible',
        Icons.remove_shopping_cart_rounded,
      );
    } else if (m.contains('minimum')) {
      c = (
        OrderErrorKind.belowMinimum,
        'Montant insuffisant',
        Icons.payments_outlined,
      );
    } else if (m.contains('panier') && m.contains('vide')) {
      c = (
        OrderErrorKind.emptyCart,
        'Panier vide',
        Icons.shopping_cart_outlined,
      );
    } else if (m.contains('adresse')) {
      c = (OrderErrorKind.address, 'Problème d\'adresse', Icons.location_off);
    } else if (m.contains('promo')) {
      c = (OrderErrorKind.promo, 'Code promo refusé', Icons.local_offer);
    } else {
      c = (
        OrderErrorKind.generic,
        'Commande non créée',
        Icons.error_outline_rounded,
      );
    }
    return OrderErrorPresentation(
      kind: c.$1,
      title: c.$2,
      message: message,
      icon: c.$3,
    );
  }
}
