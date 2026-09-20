// A-01 / U-03 / R-05 — la matrice de navigation, éprouvée exhaustivement.
//
// `resolveRedirect` est une fonction pure : phase × emplacement × `from` → une
// destination ou `null`. Cette forme n'est pas cosmétique, c'est ce qui rend la
// matrice testable en entier sans monter d'arbre de widgets, sans réseau et
// sans Firebase — donc en quelques millisecondes, donc réellement exécutée.
//
// La propriété la plus importante est en fin de fichier : **aucune boucle**.
// Elle est vérifiée par itération du redirect jusqu'à point fixe, sur toutes
// les combinaisons, plutôt que par relecture attentive du code.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/routing/app_router.dart';
import 'package:lilia_app/routing/session_phase.dart';

/// Applique le redirect une fois. `null` = « reste où tu es ».
String? redirige(SessionPhase phase, String emplacement) {
  final uri = Uri.parse(emplacement);
  return resolveRedirect(
    phase: phase,
    matchedLocation: uri.path,
    uri: uri,
  );
}

/// Applique le redirect jusqu'à ce qu'il rende `null`, et rend l'emplacement
/// final. Lève si ça ne converge pas — c'est le test de non-bouclage.
String stabilise(SessionPhase phase, String depart, {int limite = 10}) {
  var courant = depart;
  final vus = <String>[depart];
  for (var i = 0; i < limite; i++) {
    final suivant = redirige(phase, courant);
    if (suivant == null) return courant;
    if (vus.contains(suivant)) {
      fail('Boucle de redirection : ${vus.join(" → ")} → $suivant');
    }
    vus.add(suivant);
    courant = suivant;
  }
  fail('Pas de point fixe après $limite tours : ${vus.join(" → ")}');
}

// Un échantillon représentatif de chaque famille de routes.
//
// ⚠️ Ces deux listes étaient **une seule**, nommée `_protegees`, et elle
// contenait l'accueil, le panier, la fiche vendeur et les avis. C'était exact
// tant que tout exigeait une session ; ça ne l'est plus. Les garder ensemble
// aurait fait passer le mur d'inscription pour la règle.

/// Découverte : accessible sans compte.
const _decouverte = <String>[
  '/',
  '/cart',
  '/restaurant/12',
  '/product-detail',
  '/search',
  '/reviews',
];

/// Transaction : exige une session.
const _transaction = <String>[
  '/commandes',
  '/commandes/abc-123',
  '/profile',
  '/profile/favoris',
  '/profile/address',
  '/order-success',
  '/cart/delivery-options',
  '/cart/delivery-options/checkout',
];

/// Toutes les routes métier, quel que soit leur côté de la frontière.
const _metier = <String>[..._decouverte, ..._transaction];

/// Les écrans d'authentification eux-mêmes.
const _publiques = <String>['/signin', '/signup'];

void main() {
  group('BOOTSTRAPPING — on ne montre rien qu’on devrait retirer ensuite', () {
    test('l’écran de démarrage se garde lui-même', () {
      expect(redirige(SessionPhase.bootstrapping, '/splash'), isNull);
    });

    test('l’accueil n’est JAMAIS monté pendant le bootstrap (U-03)', () {
      // Le cœur d'U-03 : l'`initialLocation` était `/`, et le redirect rendait
      // `null` pendant le chargement. HomeScreen se montait donc — avec ses
      // quatre appels réseau — pour un client qu'on allait renvoyer au login.
      expect(redirige(SessionPhase.bootstrapping, '/'), startsWith('/splash'));
    });

    test('toute route métier est mise en attente sur le démarrage', () {
      for (final route in _metier) {
        expect(
          redirige(SessionPhase.bootstrapping, route),
          startsWith('/splash'),
          reason: route,
        );
      }
    });

    test('les écrans d’authentification aussi : on ne sait pas encore', () {
      for (final route in _publiques) {
        expect(
          redirige(SessionPhase.bootstrapping, route),
          startsWith('/splash'),
          reason: route,
        );
      }
    });

    test('la destination demandée survit au bootstrap', () {
      // Notification tapée alors que l'application était tuée : elle demande
      // `/commandes/xyz` avant que Firebase ait répondu.
      final vers = redirige(SessionPhase.bootstrapping, '/commandes/xyz')!;
      expect(Uri.parse(vers).queryParameters['from'], '/commandes/xyz');
    });
  });

  group('ONBOARDING_REQUIRED', () {
    test('tout mène à l’onboarding', () {
      for (final route in [..._metier, ..._publiques, '/splash']) {
        expect(
          redirige(SessionPhase.onboardingRequired, route),
          '/onboarding',
          reason: route,
        );
      }
    });

    test('l’onboarding se garde lui-même', () {
      expect(redirige(SessionPhase.onboardingRequired, '/onboarding'), isNull);
    });

    /// ⚠️ Sans session, cette sortie valait `/signin`. C'était le mur
    /// d'inscription resté debout à l'endroit où il fait le plus de dégâts :
    /// la toute première ouverture, juste après un carrousel qui vient de
    /// promettre un catalogue. Le seul public qui n'a jamais rien vu de Lilia
    /// Food était précisément celui à qui on demandait un compte d'abord.
    test('une fois terminé, on en sort par l’ACCUEIL, avec ou sans session', () {
      expect(redirige(SessionPhase.unauthenticated, '/onboarding'), '/');
      expect(redirige(SessionPhase.authenticated, '/onboarding'), '/');
    });
  });

  group('UNAUTHENTICATED', () {
    test('une route de TRANSACTION renvoie au login', () {
      for (final route in _transaction) {
        expect(
          redirige(SessionPhase.unauthenticated, route),
          startsWith('/signin'),
          reason: route,
        );
      }
    });

    /// Le pendant, et le plus important des deux : ce qui relève de la
    /// découverte s'ouvre sans rien demander.
    test('une route de DÉCOUVERTE est servie telle quelle', () {
      for (final route in _decouverte) {
        expect(
          redirige(SessionPhase.unauthenticated, route),
          isNull,
          reason: route,
        );
      }
    });

    test('R-05 — la destination demandée est mémorisée', () {
      expect(
        redirige(SessionPhase.unauthenticated, '/commandes/abc'),
        '/signin?from=%2Fcommandes%2Fabc',
      );
    });

    test('R-05 — les destinations de transaction citées par la Phase 2', () {
      for (final cible in const [
        '/commandes',
        '/profile',
        '/cart/delivery-options/checkout',
        '/order-success',
      ]) {
        final vers = redirige(SessionPhase.unauthenticated, cible)!;
        expect(Uri.parse(vers).path, '/signin');
        expect(Uri.parse(vers).queryParameters['from'], cible, reason: cible);
      }
    });

    test('les écrans d’authentification sont laissés tranquilles', () {
      for (final route in _publiques) {
        expect(redirige(SessionPhase.unauthenticated, route), isNull);
      }
    });

    test('le `from` déjà posé n’est pas réécrit à chaque évaluation', () {
      // Le redirect s'exécute plusieurs fois par navigation. S'il reconstruisait
      // l'emplacement au lieu de rendre `null`, chaque tour produirait une
      // nouvelle URL — et go_router s'arrêterait sur `redirectLimit`.
      expect(
        redirige(SessionPhase.unauthenticated, '/signin?from=%2Fprofile'),
        isNull,
      );
    });

    test('sortie du démarrage sans session', () {
      // Destination de transaction : on passe par la connexion, en la gardant.
      expect(
        redirige(SessionPhase.unauthenticated, '/splash?from=%2Fcommandes'),
        '/signin?from=%2Fcommandes',
      );
      // Rien de demandé : l'accueil, qui est public. C'est ici que vivait le
      // mur d'inscription — un `/signin` inconditionnel.
      expect(redirige(SessionPhase.unauthenticated, '/splash'), '/');
      // Destination de découverte (lien partagé vers un vendeur) : on l'ouvre.
      expect(
        redirige(SessionPhase.unauthenticated, '/splash?from=%2Frestaurant%2F12'),
        '/restaurant/12',
      );
    });
  });

  group('AUTHENTICATED', () {
    test('les routes protégées sont servies telles quelles', () {
      for (final route in _metier) {
        expect(redirige(SessionPhase.authenticated, route), isNull,
            reason: route);
      }
    });

    test('sans destination, la connexion mène à l’accueil', () {
      for (final route in _publiques) {
        expect(redirige(SessionPhase.authenticated, route), '/');
      }
    });

    test('R-05 — avec destination, la connexion y mène', () {
      expect(
        redirige(SessionPhase.authenticated, '/signin?from=%2Fcommandes%2Fabc'),
        '/commandes/abc',
      );
      expect(
        redirige(SessionPhase.authenticated, '/signup?from=%2Fprofile'),
        '/profile',
      );
    });

    test('sortie du démarrage avec session', () {
      expect(redirige(SessionPhase.authenticated, '/splash'), '/');
      expect(
        redirige(SessionPhase.authenticated, '/splash?from=%2Fprofile'),
        '/profile',
      );
    });

    test('une destination hostile est ignorée, pas suivie', () {
      // Redirection ouverte : le paramètre vient d'un lien, pas de l'app.
      for (final hostile in const [
        'https%3A%2F%2Fexemple.com',
        '%2F%2Fexemple.com',
        'commandes%2Fabc',
      ]) {
        expect(
          redirige(SessionPhase.authenticated, '/signin?from=$hostile'),
          '/',
          reason: hostile,
        );
      }
    });

    test('un `from` pointant sur le login ne boucle pas', () {
      expect(
        redirige(SessionPhase.authenticated, '/signin?from=%2Fsignin'),
        '/',
      );
    });

    test('le `from` n’est lu que sur les emplacements de transit', () {
      // Un `?from=` traînant sur une route métier ne doit pas provoquer de saut.
      expect(
        redirige(SessionPhase.authenticated, '/profile?from=%2Fcart'),
        isNull,
      );
    });
  });

  group('aucune boucle, quelle que soit la combinaison', () {
    test('toute phase × toute route converge en un point fixe', () {
      final routes = [
        ..._metier,
        ..._publiques,
        '/splash',
        '/onboarding',
        '/splash?from=%2Fprofile',
        '/signin?from=%2Fcommandes%2Fabc',
        '/signup?from=%2Fcart',
        '/signin?from=%2Fsignin',
        '/signin?from=https%3A%2F%2Fexemple.com',
      ];
      for (final phase in SessionPhase.values) {
        for (final route in routes) {
          // `stabilise` échoue de lui-même sur une boucle ou une divergence.
          final arrivee = stabilise(phase, route);
          expect(arrivee, isNotEmpty, reason: '$phase depuis $route');
        }
      }
    });

    test('chaque phase a une destination terminale cohérente', () {
      expect(stabilise(SessionPhase.bootstrapping, '/profile'),
          startsWith('/splash'));
      expect(stabilise(SessionPhase.onboardingRequired, '/profile'),
          '/onboarding');
      expect(stabilise(SessionPhase.unauthenticated, '/profile'),
          '/signin?from=%2Fprofile');
      expect(stabilise(SessionPhase.authenticated, '/profile'), '/profile');
    });

    test('le parcours complet d’un lancement à froid sans session', () {
      // /splash?from=/commandes/abc  →(résolu, pas de session)→ /signin?from=…
      // →(connexion)→ /commandes/abc
      const demande = '/commandes/abc';
      final versSplash = redirige(SessionPhase.bootstrapping, demande)!;
      final versLogin = stabilise(SessionPhase.unauthenticated, versSplash);
      expect(versLogin, '/signin?from=%2Fcommandes%2Fabc');
      final apresConnexion = stabilise(SessionPhase.authenticated, versLogin);
      expect(apresConnexion, demande);
    });

    test('le parcours complet d’un lancement à froid avec session', () {
      const demande = '/commandes/abc';
      final versSplash = redirige(SessionPhase.bootstrapping, demande)!;
      expect(stabilise(SessionPhase.authenticated, versSplash), demande);
    });
  });
}
