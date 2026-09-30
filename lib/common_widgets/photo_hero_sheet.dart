import 'package:flutter/material.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Photo dominante en haut, feuille arrondie qui la chevauche en bas.
///
/// Structure de l'onboarding et des écrans invités (UI Refresh). La photo est
/// **décorative** : exclue de la sémantique, c'est le titre de la feuille qui
/// porte le sens. Elle est décodée à la largeur affichée (`cacheWidth`), jamais
/// à sa taille native.
class PhotoHeroSheet extends StatelessWidget {
  const PhotoHeroSheet({
    super.key,
    required this.image,
    required this.child,
    this.alignment = Alignment.center,
    this.photoFraction = 0.58,
    this.overlap = 24,
  });

  /// Chemin de l'asset (`assets/onboarding/…`).
  final String image;

  /// Point focal de la photo dans le cadre (`BoxFit.cover`).
  final Alignment alignment;

  /// Part de la hauteur disponible donnée à la photo.
  final double photoFraction;

  /// Hauteur dont la feuille chevauche la photo.
  final double overlap;

  /// Contenu de la feuille. À l'appelant de le rendre défilable si le texte
  /// agrandi peut dépasser.
  final Widget child;

  /// Le fournisseur d'image exact qu'affiche [PhotoHeroSheet] pour une largeur
  /// donnée : le passer à `precacheImage` réchauffe **la même** entrée de cache.
  static ImageProvider providerFor(
    String image,
    double logicalWidth,
    double devicePixelRatio,
  ) => ResizeImage(
    AssetImage(image),
    width: (logicalWidth * devicePixelRatio).round(),
  );

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sheetColor = Theme.of(context).scaffoldBackgroundColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final photoHeight = constraints.maxHeight * photoFraction;
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: providerFor(image, constraints.maxWidth, dpr),
                    fit: BoxFit.cover,
                    alignment: alignment,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                  ),
                  // Bord inférieur assombri : la feuille se détache de la
                  // photo quelle que soit sa luminosité.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.6, 1],
                        colors: [Color(0x00000000), Color(0x3D000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: photoHeight - overlap,
              left: 0,
              right: 0,
              bottom: 0,
              // `Material` et non `DecoratedBox` : les boutons et tuiles de la
              // feuille peignent leur onde d'appui sur le Material le plus
              // proche ; un fond décoré intermédiaire la cacherait.
              child: Material(
                color: sheetColor,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(LiliaRadius.xl),
                  ),
                ),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
