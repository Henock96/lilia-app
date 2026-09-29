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
