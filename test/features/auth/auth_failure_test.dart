// T-01 / T-02 — Traduction des échecs d'authentification.
//
// Ces tests fixent le contrat qui manquait : **aucune erreur technique ne doit
// atteindre l'écran**. Avant, trois chemins y menaient et n'étaient couverts par
// aucun test :
//
//  1. `firebase_auth_error_handler` ne connaissait que 8 codes sur la quinzaine
//     que Firebase émet — `network-request-failed`, le plus fréquent sur la 4G
//     de Brazzaville, tombait dans « Une erreur inconnue est survenue » ;
//  2. `GoogleSignInException` n'était mappée nulle part, si bien qu'une simple
//     **annulation** s'affichait au client sous la forme
//     `GoogleSignInException(code GoogleSignInExceptionCode.canceled, null, null)` ;
//  3. le repository levait 14 `Exception('…')` bruts, rendus avec le préfixe
//     `Exception: ` par les snackbars.
//
// La garde décisive est `_neJamaisMontrerDeTechnique` : elle est appliquée à
// **chaque** message produit, quel que soit le chemin.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';

void main() {
  group('T-01 — codes Firebase', () {
    final cas = <String, AuthFailureKind>{
      'invalid-credential': AuthFailureKind.badCredentials,
      'wrong-password': AuthFailureKind.badCredentials,
      // Neutralisé volontairement : distinguer « aucun compte » de « mauvais
      // mot de passe » permet d'énumérer les adresses inscrites.
      'user-not-found': AuthFailureKind.badCredentials,
      'invalid-email': AuthFailureKind.invalidEmail,
      'user-disabled': AuthFailureKind.accountDisabled,
      'email-already-in-use': AuthFailureKind.emailAlreadyInUse,
      'weak-password': AuthFailureKind.weakPassword,
      'too-many-requests': AuthFailureKind.rateLimited,
      'network-request-failed': AuthFailureKind.network,
      'requires-recent-login': AuthFailureKind.requiresRecentLogin,
      'operation-not-allowed': AuthFailureKind.operationNotAllowed,
      'credential-already-in-use': AuthFailureKind.accountConflict,
      'account-exists-with-different-credential':
          AuthFailureKind.accountConflict,
      'user-token-expired': AuthFailureKind.sessionExpired,
      'user-token-revoked': AuthFailureKind.sessionExpired,
      'internal-error': AuthFailureKind.unknown,
      'un-code-que-firebase-inventera-demain': AuthFailureKind.unknown,
    };

    cas.forEach((code, attendu) {
      test('$code → $attendu', () {
        final failure = mapAuthError(FirebaseAuthException(code: code));

        expect(failure.kind, attendu);
        _neJamaisMontrerDeTechnique(failure);
      });
    });

    test('le message technique de Firebase ne traverse jamais', () {
      // C'est exactement ce que l'écran « mot de passe oublié » affichait.
      final failure = mapAuthError(
        FirebaseAuthException(
          code: 'user-not-found',
          message:
              'There is no user record corresponding to this identifier. '
              'The user may have been deleted.',
        ),
      );

      expect(failure.message, isNot(contains('user record')));
      _neJamaisMontrerDeTechnique(failure);
    });

    test('réseau : le message dit quoi faire', () {
      final failure = mapAuthError(
        FirebaseAuthException(code: 'network-request-failed'),
      );

      expect(failure.message.toLowerCase(), contains('réseau'));
    });

    test('trop de tentatives : le message dit d’attendre', () {
      final failure = mapAuthError(
        FirebaseAuthException(code: 'too-many-requests'),
      );

      expect(failure.message.toLowerCase(), contains('tentatives'));
    });
  });

  group('T-02 — Google Sign-In', () {
    test('annulation → silencieuse, aucun message', () {
      final failure = mapAuthError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      );

      expect(failure.kind, AuthFailureKind.cancelled);
      expect(failure.isSilent, isTrue);
      expect(failure.message, isEmpty);
    });

    test('interruption → silencieuse elle aussi', () {
      // L'utilisateur n'a rien demandé : une bascule d'application ou un appel
      // entrant interrompt le flux. Ce n'est pas plus une erreur qu'un abandon.
      final failure = mapAuthError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.interrupted,
        ),
      );

      expect(failure.isSilent, isTrue);
    });

    test('erreur de configuration → message générique, jamais la description',
        () {
      final failure = mapAuthError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'PlatformException(sign_in_failed, ApiException: 10)',
        ),
      );

      expect(failure.isSilent, isFalse);
      expect(failure.message, isNot(contains('PlatformException')));
      _neJamaisMontrerDeTechnique(failure);
    });

    test('erreur inconnue de Google → message utilisateur', () {
      final failure = mapAuthError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'network error',
        ),
      );

      _neJamaisMontrerDeTechnique(failure);
    });
  });

  group('ApiException — la synchronisation backend', () {
    test('réseau → réseau', () {
      final failure = mapAuthError(
        const ApiException('peu importe', kind: ApiErrorKind.network),
      );

      expect(failure.kind, AuthFailureKind.network);
    });

    test('délai dépassé → délai dépassé', () {
      final failure = mapAuthError(
        const ApiException('peu importe', kind: ApiErrorKind.timeout),
      );

      expect(failure.kind, AuthFailureKind.timeout);
    });

    test('401 → session expirée', () {
      final failure = mapAuthError(
        const ApiException(
          'Unauthorized',
          statusCode: 401,
          kind: ApiErrorKind.unauthorized,
        ),
      );

      expect(failure.kind, AuthFailureKind.sessionExpired);
    });

    test('le message métier du backend est conservé tel quel', () {
      // Le serveur rédige en français et nomme la cause (« Vous avez 1
      // commande(s) en cours »). Le remplacer par un générique perdrait la
      // seule information utile.
      final failure = mapAuthError(
        const ApiException(
          'Vous avez 1 commande(s) en cours.',
          statusCode: 409,
          kind: ApiErrorKind.client,
        ),
      );

      expect(failure.kind, AuthFailureKind.server);
      expect(failure.message, 'Vous avez 1 commande(s) en cours.');
    });
  });

  group('Cas limites', () {
    test('une AuthFailure repasse à l’identique (mapper idempotent)', () {
      const origine = AuthFailure(AuthFailureKind.weakPassword, 'coucou');

      expect(mapAuthError(origine), same(origine));
    });

    test('n’importe quel autre objet → inconnu, sans fuite de toString()', () {
      final failure = mapAuthError(
        StateError('Bad state: no element in _parseUser'),
      );

      expect(failure.kind, AuthFailureKind.unknown);
      expect(failure.message, isNot(contains('Bad state')));
      _neJamaisMontrerDeTechnique(failure);
    });

    test('toString() rend le message, jamais le nom de la classe', () {
      // Filet de sécurité : si un `'$error'` subsiste quelque part, le client
      // lit quand même une phrase française.
      const failure = AuthFailure(
        AuthFailureKind.network,
        'Connexion impossible.',
      );

      expect('$failure', 'Connexion impossible.');
      expect('$failure', isNot(contains('AuthFailure')));
    });
  });
}

/// La règle qui vaut pour tous les messages produits par le mapper.
void _neJamaisMontrerDeTechnique(AuthFailure failure) {
  if (failure.isSilent) {
    expect(failure.message, isEmpty);
    return;
  }

  expect(failure.message, isNotEmpty);

  const interdits = <String>[
    'Exception',
    'firebase_auth/',
    'FirebaseAuthException',
    'GoogleSignInException',
    'PlatformException',
    'network-request-failed',
    'Instance of',
    'null',
  ];
  for (final motif in interdits) {
    expect(
      failure.message,
      isNot(contains(motif)),
      reason: '« $motif » ne doit jamais être montré au client',
    );
  }

  // Un message destiné à un humain se termine par une ponctuation et commence
  // par une majuscule — un code technique, non.
  expect(failure.message.trim(), endsWith('.'));
  expect(failure.message[0], failure.message[0].toUpperCase());
}
