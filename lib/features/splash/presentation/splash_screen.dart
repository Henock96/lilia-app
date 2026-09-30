import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Ce qu'on montre pendant que la session se résout.
///
/// ## Pourquoi cet écran existe
///
/// L'`initialLocation` du routeur était `/` — l'accueil. Tant que Firebase
/// n'avait pas répondu, le `redirect` rendait `null` (« laisse passer »), avec
/// ce commentaire : *« éviter le clignotement / flash vers la page de
/// connexion »*. Le remède déplaçait le problème. Au lieu d'un flash vers le
/// login, on avait le **montage complet de l'accueil** — `HomeScreen`,
/// `vendorsListProvider`, `bannersListProvider`, les plats populaires,
/// `notificationHistoryProvider` — pour un client qui allait être renvoyé vers
/// la connexion une frame plus tard. Soit quatre appels réseau, sur la 4G de
/// Brazzaville, à chaque lancement hors session (U-03, P-02).
///
/// ## Ce qu'il ne fait pas
///
/// **Aucune requête, aucun provider métier, aucun minuteur de sortie.** Il
/// n'attend rien lui-même et ne décide de rien : c'est le `redirect` du routeur
/// qui le quitte dès que `sessionPhase` cesse de valoir `bootstrapping`. Un
/// écran de démarrage qui porterait sa propre logique d'attente serait une
/// deuxième source de vérité sur l'état de la session — exactement ce que
/// cette phase supprime.
///
/// ## Continuité avec l'écran natif (UI Refresh, C5)
///
/// La première frame Flutter est **identique** à l'écran de lancement natif :
/// même fond ([splashBackground]), même logo blanc, même taille
/// ([splashLogoWidth]), centré sur tout l'écran. Rien n'y est animé à
/// l'arrivée : un fondu partirait d'une image différente du natif, c'est-à-dire
/// d'un saut. Le fond suit la luminosité **du système**, comme le natif (et
/// non le thème choisi dans l'application, que le natif ignore).
///
/// Le seul minuteur est d'affichage : l'indicateur de chargement n'apparaît
/// qu'après [spinnerDelay], pour qu'un démarrage rapide ne montre jamais de
/// roue. Il n'influe en rien sur la sortie.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Largeur du logo, en points logiques — la même que les ressources natives
  /// (`LaunchImage` iOS, `splash_logo` Android ≤ 11, icône Android 12+ :
  /// 148 dp, la plus grande qui tienne dans le cercle de 192 dp d'Android 12).
  static const double splashLogoWidth = 148;

  /// Délai avant d'afficher l'indicateur de chargement.
  static const Duration spinnerDelay = Duration(milliseconds: 800);

  /// Fond du lancement : `orange600` en clair (blanc 4,94:1), `orange700` en
  /// sombre (blanc 7,5:1). Les mêmes valeurs que `LaunchBackground` (iOS) et
  /// `splash_background` (Android).
  static Color splashBackground(Brightness systemBrightness) =>
      systemBrightness == Brightness.dark
      ? LiliaColors.orange700
      : LiliaColors.orange600;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _spinnerTimer;
  bool _showSpinner = false;

  @override
  void initState() {
    super.initState();
    _spinnerTimer = Timer(SplashScreen.spinnerDelay, () {
      if (mounted) setState(() => _showSpinner = true);
    });
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = SplashScreen.splashBackground(
      MediaQuery.platformBrightnessOf(context),
    );
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Image.asset(
                'assets/branding/logo_mark_white.png',
                width: SplashScreen.splashLogoWidth,
                semanticLabel: 'Lilia Food',
              ),
            ),
            // Sous le logo, hors du centre : le logo ne bouge pas quand la
            // roue apparaît.
            Align(
              alignment: const Alignment(0, 0.45),
              child: SizedBox(
                width: 28,
                height: 28,
                child: _showSpinner
                    ? Semantics(
                        label: 'Chargement en cours',
                        // La roue elle-même reste : c'est une information
                        // (« ça charge »), pas une décoration. Seule son
                        // entrée en fondu saute en « réduire les animations ».
                        child: _fadeIn(
                          reduceMotion,
                          const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fadeIn(bool reduceMotion, Widget child) => reduceMotion
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.base,
          curve: AppMotion.curve,
          builder: (_, value, child) => Opacity(opacity: value, child: child),
          child: child,
        );
}
