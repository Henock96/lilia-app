import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/cart/data/cart_repository.dart';
import 'package:lilia_app/features/commandes/domain/order_error_presentation.dart';

void main() {
  group('OrderErrorPresentation — P3-05', () {
    test('délai dépassé : issue inconnue, jamais « échec »', () {
      final p = OrderErrorPresentation.from(
        const ApiException('x', kind: ApiErrorKind.timeout),
      );
      expect(p.kind, OrderErrorKind.outcomeUnknown);
      expect(p.message, contains('peut-être été enregistrée'));
      expect(p.title, isNot(contains('Erreur')));
    });

    test('pas de réseau : rien n\'est parti', () {
      final p = OrderErrorPresentation.from(
        const ApiException('x', kind: ApiErrorKind.network),
      );
      expect(p.kind, OrderErrorKind.offline);
    });

    test('401 : session expirée, panier conservé', () {
      final p = OrderErrorPresentation.from(
        const ApiException(
          'x',
          statusCode: 401,
          kind: ApiErrorKind.unauthorized,
        ),
      );
      expect(p.kind, OrderErrorKind.sessionExpired);
      expect(p.message, contains('panier est conservé'));
    });

    test('refus métier : le message du serveur, classé', () {
      final p = OrderErrorPresentation.from(
        const ApiException(
          'Le restaurant est actuellement fermé.',
          statusCode: 400,
          kind: ApiErrorKind.client,
        ),
      );
      expect(p.kind, OrderErrorKind.vendorClosed);
      expect(p.message, 'Le restaurant est actuellement fermé.');
    });

    test('500 : aucun texte anglais du framework', () {
      final p = OrderErrorPresentation.from(
        const ApiException(
          'Internal server error',
          statusCode: 500,
          kind: ApiErrorKind.server,
        ),
      );
      expect(p.message, isNot(contains('Internal')));
      expect(p.kind, OrderErrorKind.generic);
    });

    test('erreur de programmation : message générique', () {
      final p = OrderErrorPresentation.from(TypeError());
      expect(p.message, isNot(contains('TypeError')));
    });
  });

  group('OrderErrorPresentation — 409 du checkout (C-20)', () {
    ApiException conflit(String message, {String? code}) => ApiException(
          message,
          statusCode: 409,
          kind: ApiErrorKind.client,
          code: code,
        );

    test('« déjà en cours de traitement » : issue inconnue, pas un échec', () {
      final p = OrderErrorPresentation.from(
        conflit('Une commande identique est déjà en cours de traitement.'),
      );
      expect(p.kind, OrderErrorKind.outcomeUnknown);
      expect(p.title, isNot('Commande non créée'));
      expect(p.message, contains('Mes commandes'));
    });

    test('« panier déjà commandé » : la commande existe', () {
      final p = OrderErrorPresentation.from(
        conflit('Ce panier vient déjà d’être commandé. Consultez « Mes commandes ».'),
      );
      expect(p.kind, OrderErrorKind.alreadyPlaced);
      expect(p.title, 'Commande déjà enregistrée');
    });

    test('panier modifié (code serveur) : message du serveur', () {
      final p = OrderErrorPresentation.from(
        conflit('Les options de « Poulet » ont changé.', code: 'MODIFIER_CHANGED'),
      );
      expect(p.kind, OrderErrorKind.cartChanged);
      expect(p.message, contains('Poulet'));
    });

    test('409 inconnu : retombe sur le tri historique', () {
      final p = OrderErrorPresentation.from(conflit('Autre conflit.'));
      expect(p.kind, OrderErrorKind.generic);
    });
  });

  group('userFacingErrorMessage — exceptions rédigées pour l\'écran', () {
    test('CartException : son message', () {
      expect(
        userFacingErrorMessage(CartException('Produit épuisé.')),
        'Produit épuisé.',
      );
    });

    test('AuthFailure : son message', () {
      expect(
        userFacingErrorMessage(
          const AuthFailure(AuthFailureKind.network, 'Pas de connexion.'),
        ),
        'Pas de connexion.',
      );
    });
  });
}
