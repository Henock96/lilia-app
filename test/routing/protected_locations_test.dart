// La frontière « découvrir / transiger », éprouvée route par route.
//
// Une table d'exceptions se dégrade en silence : la route ajoutée demain n'y
// figure pas, tombe du côté public par omission, et personne ne s'en aperçoit
// avant qu'un écran authentifié ne s'ouvre vide. Le test d'EXHAUSTIVITÉ
// ci-dessous impose de classer chaque route de `AppRoutes` — il échoue sur
// celle qu'on a oubliée, en la nommant.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/routing/protected_locations.dart';

void main() {
  group('découverte — aucune session demandée', () {
    const publics = <String>[
      '/', // accueil
      '/restaurant/abc', // fiche vendeur
      '/product-detail', // fiche produit
      '/menu-detail',
      '/search',
      '/cart', // le panier se compose et se regarde sans compte
      '/reviews/resto-1', // lire les avis d’un vendeur
    ];

    for (final emplacement in publics) {
      test('$emplacement est public', () {
        expect(requiresAuthentication(emplacement), isFalse);
      });
    }
  });

  group('transaction — session exigée', () {
    const proteges = <String>[
      '/commandes',
      '/commandes/abc',
      '/commandes/abc/tracking',
      '/commandes/paiement/pay-1',
      '/profile',
      '/profile/address',
      '/profile/favoris/details',
      '/profile/draft-orders',
      '/order-success',
      '/cart/delivery-options', // ⚠️ LA frontière du parcours d'achat
      '/cart/delivery-options/checkout',
      '/notifications',
      // ⚠️ Le segment du milieu est un paramètre : `/reviews/:restaurantId/write`.
      // Une comparaison de préfixe littérale ne l'aurait pas reconnu, et
      // rédiger un avis serait redevenu public en silence le jour où la route
      // est devenue adressable.
      '/reviews/resto-1/write',
    ];

    for (final emplacement in proteges) {
      test('$emplacement exige une session', () {
        expect(requiresAuthentication(emplacement), isTrue);
      });
    }
  });

  group('forme du chemin', () {
    test('la barre finale ne change rien', () {
      expect(requiresAuthentication('/commandes/'), isTrue);
      expect(requiresAuthentication('/cart/'), isFalse);
    });

    /// `startsWith` nu protégerait `/cartographie` parce qu'il commence par
    /// `/cart`. La frontière doit tomber sur un séparateur de segment.
    test('un préfixe partiel de segment ne protège pas', () {
      expect(requiresAuthentication('/commandes-publiques'), isFalse);
      expect(requiresAuthentication('/profiles'), isFalse);
      expect(requiresAuthentication('/notifications-publiques'), isFalse);
    });

    test('la racine reste publique', () {
      expect(requiresAuthentication('/'), isFalse);
    });
  });

  /// **Le test qui fait le travail.**
  ///
  /// Chaque route de l'application doit être explicitement rangée d'un côté ou
  /// de l'autre. Une route ajoutée sans décision fait échouer ce test, ce qui
  /// est exactement le but : c'est une décision produit, pas un défaut par
  /// omission.
  test('exhaustivité — chaque route est classée', () {
    // Écrans de transit : ni découverte, ni transaction. Ils ont leur propre
    // traitement dans `resolveRedirect` (§1, §2, §3) et n'ont rien à faire
    // dans la table.
    const transit = {
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.signIn,
      AppRoutes.signUp,
    };

    // Décision, route par route. Recopiée à la main **volontairement** : la
    // dériver de `requiresAuthentication` ferait un test qui vérifie que la
    // fonction sait se lire elle-même.
    const attendu = <AppRoutes, bool>{
      AppRoutes.home: false,
      AppRoutes.restaurantDetail: false,
      AppRoutes.productDetail: false,
      AppRoutes.menuDetail: false,
      AppRoutes.search: false,
      AppRoutes.cart: false,
      AppRoutes.reviews: false,
      AppRoutes.commandes: true,
      AppRoutes.orderDetail: true,
      AppRoutes.orderTracking: true,
      AppRoutes.paymentPending: true,
      AppRoutes.profile: true,
      AppRoutes.editProfile: true,
      AppRoutes.about: true,
      AppRoutes.address: true,
      AppRoutes.changePassword: true,
      AppRoutes.favoris: true,
      AppRoutes.favoriteDetail: true,
      AppRoutes.draftOrders: true,
      AppRoutes.deliveryOptions: true,
      AppRoutes.checkout: true,
      AppRoutes.orderSuccess: true,
      AppRoutes.notifications: true,
      AppRoutes.writeReview: true,
    };

    final nonClassees = AppRoutes.values
        .where((r) => !transit.contains(r) && !attendu.containsKey(r))
        .toList();
    expect(
      nonClassees,
      isEmpty,
      reason:
          'Routes sans décision publique/protégée : $nonClassees. '
          'Rangez-les dans `protected_locations.dart`, puis ici.',
    );
  });

  test('la table n’expose que des chemins absolus', () {
    for (final prefixe in protectedLocationPrefixes) {
      expect(
        prefixe.startsWith('/'),
        isTrue,
        reason:
            '« $prefixe » est un segment de sous-route, pas un emplacement. '
            'Il ne pourra jamais correspondre à un `matchedLocation`.',
      );
    }
  });
}
