import 'package:flutter/material.dart';

/// Ce qu'on montre pendant que la session se résout.
///
/// ## Pourquoi cet écran existe
///
/// L'`initialLocation` du routeur était `/` — l'accueil. Tant que Firebase
/// n'avait pas répondu, le `redirect` rendait `null` (« laisse passer »), avec
/// ce commentaire : *« éviter le clignotement / flash vers la page de
/// connexion »*. Le remède déplaçait le problème. Au lieu d'un flash vers le
/// login, on avait le **montage complet de l'accueil** — `HomeScreen`,
/// `vendorsListProvider`, `bannersListProvider`, `popularProductsProvider`,
/// `notificationHistoryProvider` — pour un client qui allait être renvoyé vers
/// la connexion une frame plus tard. Soit quatre appels réseau, sur la 4G de
/// Brazzaville, à chaque lancement hors session (U-03, P-02).
///
/// ## Ce qu'il ne fait pas
///
/// **Aucune requête, aucun provider métier, aucun minuteur.** Il n'attend rien
/// lui-même et ne décide de rien : c'est le `redirect` du routeur qui le quitte
/// dès que `sessionPhase` cesse de valoir `bootstrapping`. Un écran de
/// démarrage qui porterait sa propre logique d'attente serait une deuxième
/// source de vérité sur l'état de la session — exactement ce que cette phase
/// supprime.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/logo1.jpg',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                // Décoratif : le nom de l'application est annoncé juste en
                // dessous, le répéter ferait doublon au lecteur d'écran.
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lilia Food',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: Semantics(
                label: 'Chargement en cours',
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
