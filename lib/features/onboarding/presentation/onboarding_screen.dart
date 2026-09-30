import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/page_dots.dart';
import 'package:lilia_app/common_widgets/photo_hero_sheet.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Une page de l'onboarding : une photo réelle, un titre, une phrase.
class OnboardingPage {
  const OnboardingPage({
    required this.image,
    required this.title,
    required this.description,
    this.alignment = Alignment.center,
    this.photoFraction = 0.58,
  });

  final String image;
  final String title;
  final String description;
  final Alignment alignment;
  final double photoFraction;
}

/// Textes imposés par le plan UI Refresh (§7.3), vérifiés contre le produit :
/// types de vendeurs (`vendorType`), moyens de paiement du checkout (MTN MoMo,
/// Airtel Money), livraison **et** retrait, suivi par la timeline de commande.
/// Aucune promesse de délai ni de moyen de paiement que l'app n'offre pas.
const onboardingPages = [
  OnboardingPage(
    image: 'assets/onboarding/onb1.webp',
    title: 'Les bonnes adresses de Brazzaville',
    description:
        'Restaurants, cuisines maison, pâtisseries : tout au même endroit.',
    alignment: Alignment(0, -0.1),
  ),
  OnboardingPage(
    image: 'assets/onboarding/onb2.webp',
    title: 'Commandez en quelques gestes',
    description: 'Payez par MTN MoMo ou Airtel Money.',
    alignment: Alignment(0, -0.3),
  ),
  // Photo de secours (1024×640 d'origine, livrée d'un tiers) : cadre réduit
  // pour limiter l'agrandissement, en attendant une photo locale.
  OnboardingPage(
    image: 'assets/onboarding/onb3.webp',
    title: 'Livré chez vous ou à emporter',
    description: "Suivez votre commande jusqu'à la remise.",
    alignment: Alignment(0, 0.3),
    photoFraction: 0.48,
  ),
];

/// Premier lancement : trois pages photo, puis la main au routeur.
///
/// « Passer » et « Commencer » font **la même chose** : `completeOnboarding()`
/// (clé `onboarding_completed`, inchangée). L'écran ne navigue jamais
/// lui-même — `sessionPhase` quitte `onboardingRequired` et le `redirect`
/// décide de la suite (connexion, ou accueil si une session existe déjà).
///
/// Aucune animation en boucle : l'ancien écran faisait flotter ses icônes
/// indéfiniment, ce qui empêchait aussi tout `pumpAndSettle` en test.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _completing = false;

  bool get _isLast => _page == onboardingPages.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache(0);
    _precache(1);
  }

  /// Réchauffe la photo de la page [index] à la taille exacte où elle sera
  /// affichée : l'arrivée sur la page suivante ne montre pas de vide.
  void _precache(int index) {
    if (index >= onboardingPages.length) return;
    final media = MediaQuery.of(context);
    precacheImage(
      PhotoHeroSheet.providerFor(
        onboardingPages[index].image,
        media.size.width,
        media.devicePixelRatio,
      ),
      context,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(duration: AppMotion.base, curve: AppMotion.curve);
    }
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    await ref.read(onboardingStatusProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Barre d'état posée sur la photo : icônes claires.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: onboardingPages.length,
                onPageChanged: (page) {
                  setState(() => _page = page);
                  _precache(page + 1);
                },
                itemBuilder: (context, i) => _PageContent(onboardingPages[i]),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                LiliaSpacing.lg,
                LiliaSpacing.sm,
                LiliaSpacing.lg,
                LiliaSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PageDots(count: onboardingPages.length, index: _page),
                  const SizedBox(height: LiliaSpacing.lg),
                  _isLast
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _completing ? null : _complete,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                            ),
                            child: const Text('Commencer'),
                          ),
                        )
                      : Row(
                          // `spaceBetween` et non `Spacer` : avec des
                          // `Flexible`, un `Spacer` réservait une part fixe et
                          // « Suivant » s'arrêtait au milieu de l'écran.
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: TextButton(
                                onPressed: _completing ? null : _complete,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                child: const Text('Passer'),
                              ),
                            ),
                            const SizedBox(width: LiliaSpacing.md),
                            Flexible(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _next,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(120, 48),
                                ),
                                child: const Text('Suivant'),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent(this.page);

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return PhotoHeroSheet(
      image: page.image,
      alignment: page.alignment,
      photoFraction: page.photoFraction,
      // Défilable : à 2× de taille de texte, titre et phrase peuvent dépasser
      // la feuille. On ne tronque jamais.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LiliaSpacing.lg,
          LiliaSpacing.xl,
          LiliaSpacing.lg,
          LiliaSpacing.md,
        ),
        child: Column(
          children: [
            Semantics(
              header: true,
              child: Text(
                page.title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: LiliaSpacing.sm + LiliaSpacing.xs),
            Text(
              page.description,
              textAlign: TextAlign.center,
              // Inter pour la phrase : Oswald, condensé, est réservé aux titres.
              style: GoogleFonts.inter(
                textStyle: textTheme.bodyLarge,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
